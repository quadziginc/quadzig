require 'sidekiq_aws_helpers'

class PopulateTgwAttachmentsWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def perform(user_id, aws_account_id, aws_region_code)
    user = User.find(user_id)
    account = user.aws_accounts.find(aws_account_id)
    region = AwsRegion.where(region_code: aws_region_code).first
    tgw_attchs = []
    existing_tgw_attchs = []

    return unless account.creation_complete

    # TODO: Raise Error on else
    if region
      access_key, secret_key, session_token = get_aws_iam_credentials(user_id, aws_account_id)

      ec2 = Aws::EC2::Client.new(
        region: aws_region_code,
        credentials: Aws::Credentials.new(access_key, secret_key, session_token)
      )

      begin
        ec2.describe_transit_gateway_attachments({
          max_results: 1000
        }).each do |resp|
          tgw_attchs.concat(resp.transit_gateway_attachments)
        end
      # Exit if there is an issue while fetching
      rescue Aws::EC2::Errors::UnauthorizedOperation, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
        return
      end

      # TODO: N+1 Query? Optimize?
      existing_tgw_attchs = account.aws_tgw_attachments.where(region_code: aws_region_code).to_a

      tgw_attch_ids = tgw_attchs.collect { |tgw_attch| tgw_attch.transit_gateway_attachment_id }
      existing_tgw_attch_ids = existing_tgw_attchs.collect { |tgw_attch| tgw_attch.tgw_attch_id }

      tgw_attch_ids_to_destroy = existing_tgw_attch_ids - tgw_attch_ids

      es_records_to_delete = []

      tgw_attch_ids_to_destroy.each do |tgw_attch_id|
        tgw_attch = existing_tgw_attchs.detect { |attch| attch.tgw_attch_id == tgw_attch_id }
        if tgw_attch
          tgw_attch.destroy

          es_records_to_delete.append({
            id: tgw_attch.id,
            routing_key: user.id
          })

          existing_tgw_attchs.delete_if { |attch| attch.tgw_attch_id == tgw_attch_id }
        end
      end

      es_records_to_update = []

      ActiveRecord::Base.transaction do

        tgw_attchs.each do |tgw_attch|

          attributes = {
            tgw_attch_id: tgw_attch.transit_gateway_attachment_id,
            tgw_id: tgw_attch.transit_gateway_id,
            tgw_owner_id: tgw_attch.transit_gateway_owner_id,
            region_code: aws_region_code,
            resource_owner_id: tgw_attch.resource_owner_id,
            resource_type: tgw_attch.resource_type,
            resource_id: tgw_attch.resource_id,
            state: tgw_attch.state,
            tags: tgw_attch.tags,
            last_updated_at: DateTime.now
          }

          search_attributes = enrich_attributes(
            attributes,
            account,
            user,
            :tgw_attachment,
            []
          )

          existing_tgw_attch = account.aws_tgw_attachments.where(tgw_attch_id: tgw_attch.transit_gateway_attachment_id).first
          if existing_tgw_attch
            existing_tgw_attch.update(attributes)
            es_records_to_update.append({
              id: existing_tgw_attch.id,
              attributes: search_attributes,
              routing_key: user.id
            })
          else
            new_tgw_attch = account.aws_tgw_attachments.create!(attributes)
            es_records_to_update.append({
              id: new_tgw_attch.id,
              attributes: search_attributes,
              routing_key: user.id
            })
          end
        end
      end

      delete_es_docs(es_records_to_delete)
      create_es_docs(es_records_to_update)
    end
  end
end
