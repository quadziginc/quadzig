require 'sidekiq_aws_helpers'

class PopulateAwsTransitGatewaysWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def perform(user_id, aws_account_id, aws_region_code)
    user = User.find(user_id)
    account = user.aws_accounts.find(aws_account_id)
    region = AwsRegion.where(region_code: aws_region_code).first
    tgws = []
    existing_tgws = []

    return unless account.creation_complete

    # TODO: Raise Error on else
    if region
      access_key, secret_key, session_token = get_aws_iam_credentials(user_id, aws_account_id)

      ec2 = Aws::EC2::Client.new(
        region: aws_region_code,
        credentials: Aws::Credentials.new(access_key, secret_key, session_token)
      )

      begin
        ec2.describe_transit_gateways({
          max_results: 1000,
          filters: [
            {
              name: "state",
              values: ["available"],
            },
          ]
        }).each do |resp|
          tgws.concat(resp.transit_gateways)
        end
      rescue Aws::EC2::Errors::UnauthorizedOperation, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
        return
      end

      # TODO: N+1 Query? Optimize?
      existing_tgws = account.aws_tgws.where(region_code: aws_region_code).to_a

      tgw_ids = tgws.collect { |tgw| tgw.transit_gateway_id }
      existing_tgw_ids = existing_tgws.collect { |tgw| tgw.tgw_id }

      tgw_ids_to_destroy = existing_tgw_ids - tgw_ids

      es_records_to_delete = []

      tgw_ids_to_destroy.each do |tgw_id|
        tgw = existing_tgws.detect { |tgw| tgw.tgw_id == tgw_id }
        if tgw
          tgw.destroy
          es_records_to_delete.append({
            id: tgw.id,
            routing_key: user.id
          })
          existing_tgws.delete_if { |tgw| tgw.tgw_id == tgw_id }
        end
      end

      es_records_to_update = []

      ActiveRecord::Base.transaction do
        tgws.each do |tgw|
          existing_tgw = account.aws_tgws.where(tgw_id: tgw.transit_gateway_id).first

          attributes = {
            tgw_id: tgw.transit_gateway_id,
            tgw_arn: tgw.transit_gateway_arn,
            owner_id: tgw.owner_id,
            amz_side_asn: tgw.options.amazon_side_asn,
            auto_acc_shrd_attch: tgw.options.auto_accept_shared_attachments,
            tags: tgw.tags,
            region_code: aws_region_code,
            last_updated_at: DateTime.now
          }

          search_attributes = enrich_attributes(
            attributes,
            account,
            user,
            :tgw,
            []
          )

          if existing_tgw
            existing_tgw.update(attributes)
            es_records_to_update.append({
              id: existing_tgw.id,
              attributes: search_attributes,
              routing_key: user.id
            })
          else
            new_tgw = account.aws_tgws.create!(attributes)
            es_records_to_update.append({
              id: new_tgw.id,
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