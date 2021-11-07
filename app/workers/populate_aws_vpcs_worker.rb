require 'sidekiq_aws_helpers'

class PopulateAwsVpcsWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def perform(user_id, aws_account_id, aws_region_code)
    user = User.find(user_id)
    account = user.aws_accounts.find(aws_account_id)
    region = AwsRegion.where(region_code: aws_region_code).first
    vpcs = []
    existing_vpcs = []

    return unless account.creation_complete

    # TODO: Raise Error on else
    if region
      access_key, secret_key, session_token = get_aws_iam_credentials(user_id, aws_account_id)

      ec2 = Aws::EC2::Client.new(
        region: aws_region_code,
        credentials: Aws::Credentials.new(access_key, secret_key, session_token)
      )

      begin
        ec2.describe_vpcs({
          max_results: 1000
        }).each do |resp|
          vpcs.concat(resp.vpcs)
        end
      rescue Aws::EC2::Errors::UnauthorizedOperation, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
        return
      end

      if user.ignore_default_vpcs
        vpcs.filter! { |vpc| !vpc.is_default }
      end

      vpcs.filter! { |vpc| !(user.ignored_aws_vpcs.include? vpc.vpc_id) }

      # TODO: N+1 Query? Optimize?
      existing_vpcs = account.aws_vpcs.where(region_code: aws_region_code).to_a

      vpc_ids = vpcs.collect { |vpc| vpc.vpc_id }
      existing_vpc_ids = existing_vpcs.collect { |vpc| vpc.vpc_id }

      vpc_ids_to_destroy = existing_vpc_ids - vpc_ids

      es_records_to_delete = []

      vpc_ids_to_destroy.each do |vpc_id|
        vpc = existing_vpcs.detect { |vpc| vpc.vpc_id == vpc_id }
        if vpc
          vpc.destroy
          es_records_to_delete.append({
            id: vpc.id,
            routing_key: user.id
          })
          existing_vpcs.delete_if { |vpc| vpc.vpc_id == vpc_id }
        end
      end

      es_records_to_update = []

      ActiveRecord::Base.transaction do
        vpcs.each do |vpc|
          attributes = {
            vpc_id: vpc.vpc_id,
            is_default: vpc.is_default,
            tags: vpc.tags,
            region_code: aws_region_code,
            last_updated_at: DateTime.now,
            cidr_block: vpc.cidr_block
          }

          search_attributes = enrich_attributes(
            attributes,
            account,
            user,
            :vpc,
            []
          )

          existing_vpc = account.aws_vpcs.where(vpc_id: vpc.vpc_id).first
          if existing_vpc
            existing_vpc.update(attributes)
            es_records_to_update.append({
              id: existing_vpc.id,
              attributes: search_attributes,
              routing_key: user.id
            })
          else
            new_vpc = account.aws_vpcs.create!(attributes)
            es_records_to_update.append({
              id: new_vpc.id,
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
