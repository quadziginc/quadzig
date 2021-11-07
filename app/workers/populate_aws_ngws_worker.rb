require 'sidekiq_aws_helpers'

class PopulateAwsNgwsWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def perform(user_id, aws_account_id, aws_region_code)
    user = User.find(user_id)
    account = user.aws_accounts.find(aws_account_id)
    region = AwsRegion.where(region_code: aws_region_code).first

    ngws = []
    existing_ngws = []

    return unless account.creation_complete

    if region
      access_key, secret_key, session_token = get_aws_iam_credentials(user_id, aws_account_id)

      ec2 = Aws::EC2::Client.new(
        region: aws_region_code,
        credentials: Aws::Credentials.new(access_key, secret_key, session_token)
      )

      begin
        ec2.describe_nat_gateways({
          filter: [
            {
              name: "state",
              values: ["available"]
            }
          ],
          max_results: 1000
        }).each do |resp|
          ngws.concat(resp.nat_gateways)
        end
      # Exit if there is an issue while fetching
      rescue Aws::EC2::Errors::UnauthorizedOperation, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
        return
      end

      user.ignored_aws_vpcs.each do |vpc_id|
        ngws.filter! { |ngw| !(ngw.vpc_id == vpc_id) }
      end

      # user.ignored_aws_subnets.each do |subnet_id|
      #   ngws.filter! { |ngw| !(ngw.subnet_id == subnet_id) }
      # end

      # user.ignored_aws_subnets.each do |subnet_id|
      #   # subnets = account.aws_vpcs.includes(:aws_subnets).inject([]) { |subs, v| subs.concat v.aws_subnets }
      #   # subnet = subnets.find { |sub| sub.subnet_id == subnet_id }
      #   if subnet
      #     if ngw.subnet_id == 
      #     subnets.filter! { |subnet| !(subnet.vpc_id == vpc_id) }
      #   end
      # end

      if user.ignore_default_vpcs
        temp_vpcs = []
        ngws.each_slice(1000) do |one_k_ngws|
          vpc_ids = one_k_ngws.map { |ngw| ngw.vpc_id }
          ec2.describe_vpcs(vpc_ids: vpc_ids).each do |resp|
            temp_vpcs.concat(resp.vpcs)
          end
        end

        ngws.filter! do |ngw|
          vpc = temp_vpcs.find { |vpc| vpc.vpc_id == ngw.vpc_id }
          !vpc.is_default 
        end
      end

      existing_ngws = account.aws_ngws.where(region_code: aws_region_code).to_a

      ngw_ids = ngws.collect { |ngw| ngw.nat_gateway_id }
      existing_ngw_ids = existing_ngws.collect { |ngw| ngw.ngw_id }

      ngw_ids_to_destroy = existing_ngw_ids - ngw_ids

      es_records_to_delete = []

      ngw_ids_to_destroy.each do |ngw_id|
        ngw = existing_ngws.detect { |ngw| ngw.ngw_id == ngw_id }
        if ngw
          ngw.destroy
          es_records_to_delete.append({
            id: ngw.id,
            routing_key: user.id
          })
          existing_ngws.delete_if { |ngw| ngw.ngw_id == ngw_id }
        end
      end

      es_records_to_update = []

      # TODO: We need to keep the transaction block as small as possible.
      # Right now, a large number of records are touched within the block
      # which leads to a higher chance of failure. Refactor this.
      ActiveRecord::Base.transaction do
        ngws.each do |ngw|
          existing_ngw = account.aws_ngws.where(ngw_id: ngw.nat_gateway_id).first
          attributes = {
            ngw_id: ngw.nat_gateway_id,
            vpc_id: ngw.vpc_id,
            addresses: ngw.nat_gateway_addresses,
            last_updated_at: DateTime.now,
            region_code: aws_region_code,
            subnet_id: ngw.subnet_id
          }

          search_attributes = enrich_attributes(
            attributes,
            account,
            user,
            :ngw,
            [:addresses]
          )

          if existing_ngw
            existing_ngw.update(attributes)
            es_records_to_update.append({
              id: existing_ngw.id,
              attributes: search_attributes,
              routing_key: user.id
            })
          else
            created_ngw = account.aws_ngws.create!(attributes)
            es_records_to_update.append({
              id: created_ngw.id,
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
