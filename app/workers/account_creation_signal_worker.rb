require 'cfnresponse'

class AccountCreationSignalWorker
  include Sidekiq::Worker
  include Cfnresponse

  sidekiq_options queue: :accounts

  def perform
    queue_name = "AccountAddSQSQueue-quadzig-#{Rails.env}"

    AwsRegion.all.each do |region|
      queue_url = "https://sqs.#{region.region_code}.amazonaws.com/200265524545/#{queue_name}"
      sqs = Aws::SQS::Client.new(
        region: region.region_code
      )

      # Visibility Timeout should match the frequency of worker schedule
      resp = sqs.receive_message({
        queue_url: queue_url,
        max_number_of_messages: 10,
        visibility_timeout: 20
      })

      if resp.messages.count > 0
        resp.messages.each do |message|
          body = message.body
          json_body = JSON.parse body
          cfn_message = json_body["Message"]
          json_cfn_message = JSON.parse cfn_message

          # TODO: Anything different to be done for updates?
          if json_cfn_message["RequestType"] == "Create"
            account_id = json_cfn_message["ResourceProperties"]["AccountId"]
            external_id = json_cfn_message["ResourceProperties"]["ExternalId"]
            role_name = json_cfn_message["ResourceProperties"]["RoleName"]
            stack_name = json_cfn_message["ResourceProperties"]["StackName"]
            stack_id = json_cfn_message["ResourceProperties"]["StackId"]
            cf_region_code = json_cfn_message["ResourceProperties"]["RegionCode"]

            # TODO: Else?
            user_id = APP_REDIS_POOL.with do |client|
              client.get(external_id)
            end

            if user_id
              # TODO: Anything else we can do to improve security?
              user = User.find(user_id)
              
              ActiveRecord::Base.transaction do
                account = user.aws_accounts.create!(
                  name: random_name_gen,
                  iam_role_arn: role_name,
                  role_associated: true,
                  active_regions: AwsRegion.pluck(:region_code),
                  ext_reference: SecureRandom.hex(30),
                  status: 'processing',
                  external_id: external_id,
                  cf_stack_name: stack_name,
                  cf_stack_id: stack_id,
                  cf_region_code: cf_region_code
                )

                send_response(json_cfn_message, {}, "SUCCESS")
                VerifyAwsAccountAccessWorker.perform_async(user_id, account.id)

                # DELETING THE MESSAGE FROM THE QUEUE SHOULD BE THE LAST ACTION OF THIS JOB
                sqs.delete_message({
                  queue_url: queue_url,
                  receipt_handle: message.receipt_handle
                })
              end
            else
              # If we can't find a user, then this is a really old stack.
              # Just ignore this for now.
              # TODO: This is a edge case we have to handle later.
              return true
            end
          elsif json_cfn_message["RequestType"] == "Update"
            account_id = json_cfn_message["ResourceProperties"]["AccountId"]
            external_id = json_cfn_message["ResourceProperties"]["ExternalId"]
            role_name = json_cfn_message["ResourceProperties"]["RoleName"]
            stack_name = json_cfn_message["ResourceProperties"]["StackName"]
            stack_id = json_cfn_message["ResourceProperties"]["StackId"]
            cf_region_code = json_cfn_message["ResourceProperties"]["RegionCode"]
            iam_role_version = json_cfn_message["ResourceProperties"]["IAMRoleVersion"]

            cf_template_version = CfTemplateVersion.where(version: iam_role_version).first
            if cf_template_version
              # TODO: What's the worst that could happen if someone were to guess all of these
              # values and construct a CF payload to target an account belonging to a different user?
              # We will probably update the account's template version. But that's about it. So, this is not
              # a security issue right?
              account = AwsAccount.where(
                iam_role_arn: role_name,
                role_associated: true,
                status: 'created',
                external_id: external_id,
                cf_stack_name: stack_name
              ).first

              if account
                account.update(cf_template_version: cf_template_version)
              end

              send_response(json_cfn_message, {}, "SUCCESS")
              sqs.delete_message({
                queue_url: queue_url,
                receipt_handle: message.receipt_handle
              })
            end
            return true
          elsif json_cfn_message["RequestType"] == "Delete"
            account_id = json_cfn_message["ResourceProperties"]["AccountId"]
            external_id = json_cfn_message["ResourceProperties"]["ExternalId"]
            role_name = json_cfn_message["ResourceProperties"]["RoleName"]

            account = AwsAccount.unscoped.find_by(external_id: external_id, iam_role_arn: role_name, account_id: account_id)
            if account
              # account.update!(stack_signal_received: true)
              ActiveRecord::Base.transaction do
                # This will probably be confusing to users if an account suddenly disappears
                # TODO: Mark these as impaired instead of deleting them
                account.update!(
                  status: 'deleted',
                  creation_errors: ['Associated Cloudformation stack has been deleted! Please remove and re-add the account']
                )

                send_response(json_cfn_message, {}, "SUCCESS")
                # DELETING THE MESSAGE FROM THE QUEUE SHOULD BE THE LAST ACTION OF THIS JOB
                sqs.delete_message({
                  queue_url: queue_url,
                  receipt_handle: message.receipt_handle
                })
              end
            # If the user has deleted the account before deleting the stack
            else
              send_response(json_cfn_message, {}, "SUCCESS")
              # DELETING THE MESSAGE FROM THE QUEUE SHOULD BE THE LAST ACTION OF THIS JOB
              sqs.delete_message({
                queue_url: queue_url,
                receipt_handle: message.receipt_handle
              })
            end
          end
        end
      end
    end
  end
end