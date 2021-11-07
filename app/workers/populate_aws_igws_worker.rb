require 'sidekiq_aws_helpers'

class PopulateAwsIgwsWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def perform(user_id, aws_account_id, aws_region_code)
    user = User.find(user_id)
    account = user.aws_accounts.find(aws_account_id)
    region = AwsRegion.where(region_code: aws_region_code).first

    igws = []
    existing_igws = []

    return unless account.creation_complete

    if region
      access_key, secret_key, session_token = get_aws_iam_credentials(user_id, aws_account_id)

      ec2 = Aws::EC2::Client.new(
        region: aws_region_code,
        credentials: Aws::Credentials.new(access_key, secret_key, session_token)
      )

      begin
        ec2.describe_internet_gateways({
          max_results: 1000
        }).each do |resp|
          igws.concat(resp.internet_gateways)
        end
      rescue Aws::EC2::Errors::UnauthorizedOperation, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
        return
      end

      user.ignored_aws_vpcs.each do |vpc_id|
        igws.filter! { |igw| !(igw.attachments[0].vpc_id == vpc_id) }
      end

      existing_igws = account.aws_igws.where(region_code: aws_region_code).to_a
      if user.ignore_default_vpcs
        temp_vpcs = []
        igws.each_slice(1000) do |one_k_igws|
          # In case it's a detached igw, the attachments will be an empty array
          vpc_ids = one_k_igws.map { |igw| igw.attachments.empty? ? nil : igw.attachments[0].vpc_id }
          vpc_ids.compact!

          ec2.describe_vpcs(vpc_ids: vpc_ids).each do |resp|
            temp_vpcs.concat(resp.vpcs)
          end
        end

        igws.filter! do |igw|
          # In case it's a detached igw
          tgw_vpc_id = igw.attachments.empty? ? nil : igw.attachments[0].vpc_id

          vpc = temp_vpcs.find { |vpc| vpc.vpc_id == tgw_vpc_id }

          if vpc
            !vpc.is_default
          else
            false
          end
        end
      end

      igw_ids = igws.collect { |igw| igw.internet_gateway_id }
      existing_igw_ids = existing_igws.collect { |igw| igw.igw_id }
      igw_ids_to_destroy = existing_igw_ids - igw_ids

      es_records_to_delete = []

      igw_ids_to_destroy.each do |igw_id|
        igw = existing_igws.detect { |igw| igw.igw_id == igw_id }
        if igw
          igw.destroy
          es_records_to_delete.append({
            id: igw.id,
            routing_key: user.id
          })

          # TODO: Why do we explicitly delete from existing_igws if existing_igws is no
          # longer used anywhere? Same for all populate workers
          existing_igws.delete_if { |igw| igw.igw_id == igw_id }
        end
      end

      es_records_to_update = []

      # TODO: We need to keep the transaction block as small as possible.
      # Right now, a large number of records are touched within the block
      # which leads to a higher chance of failure. Refactor this.
      ActiveRecord::Base.transaction do
        igws.each do |igw|
          attributes = {
            igw_id: igw.internet_gateway_id,
            vpc_id: igw.attachments.empty? ? nil : igw.attachments[0].vpc_id,
            last_updated_at: DateTime.now,
            owner_id: igw.owner_id,
            region_code: aws_region_code
          }

          search_attributes = enrich_attributes(
            attributes,
            account,
            user,
            :igw,
            []
          )

          existing_igw = account.aws_igws.where(igw_id: igw.internet_gateway_id).first
          if existing_igw
            existing_igw.update(attributes)
            es_records_to_update.append({
              id: existing_igw.id,
              attributes: search_attributes,
              routing_key: user.id
            })
          else
            created_igw = account.aws_igws.create!(attributes)
            es_records_to_update.append({
              id: created_igw.id,
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
