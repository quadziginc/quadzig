require 'sidekiq_aws_helpers'

class PopulateAwsPeeringConnsWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def perform(user_id, account_id, aws_region_code)
    user = User.find(user_id)
    account = user.aws_accounts.find(account_id)
    region = AwsRegion.where(region_code: aws_region_code).first

    peering_conns = []
    existing_peering_conns = []

    return unless account.creation_complete

    if region
      access_key, secret_key, session_token = get_aws_iam_credentials(user_id, account_id)

      ec2 = Aws::EC2::Client.new(
        region: aws_region_code,
        credentials: Aws::Credentials.new(access_key, secret_key, session_token)
      )

      begin
        ec2.describe_vpc_peering_connections({
          max_results: 1000
        }).each do |resp|
          peering_conns.concat(resp.vpc_peering_connections)
        end
      rescue Aws::EC2::Errors::UnauthorizedOperation, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
        return
      end

      existing_peering_conns = account.aws_peering_connections.where(region_code: aws_region_code).to_a

      existing_peering_conn_ids = existing_peering_conns.collect { |conn| conn.peering_id }
      peering_conn_ids = peering_conns.collect { |conn| conn.vpc_peering_connection_id }

      peering_conn_ids_to_destroy = existing_peering_conn_ids - peering_conn_ids

      es_records_to_delete = []

      peering_conn_ids_to_destroy.each do |peering_conn_id|
        conn = existing_peering_conns.detect { |conn| conn.peering_id == peering_conn_id }
        if conn
          conn.destroy
          es_records_to_delete.append({
            id: conn.id,
            routing_key: user.id
          })
          existing_peering_conns.delete_if { |conn| conn.peering_id == peering_conn_id }
        end
      end

      es_records_to_update = []

      ActiveRecord::Base.transaction do

        peering_conns.each do |peering_conn|
          if peering_conn.status.code == "active"
            existing_peering_conn = account.aws_peering_connections.where(peering_id: peering_conn.vpc_peering_connection_id).first

            attributes = {
              peering_id: peering_conn.vpc_peering_connection_id,
              region_code: aws_region_code,
              last_updated_at: DateTime.now
            }

            search_attributes = enrich_attributes(
              attributes,
              account,
              user,
              :peering_connection,
              []
            )

            if existing_peering_conn
              existing_peering_conn.update(attributes)
              es_records_to_update.append({
                id: existing_peering_conn.id,
                attributes: search_attributes,
                routing_key: user.id
              })
            else
              conn = account.aws_peering_connections.create!(attributes)

              es_records_to_update.append({
                id: conn.id,
                attributes: search_attributes,
                routing_key: user.id
              })

              conn.create_accepter_vpc(
                cidr_block: peering_conn.accepter_vpc_info.cidr_block,
                owner_id: peering_conn.accepter_vpc_info.owner_id,
                vpc_id: peering_conn.accepter_vpc_info.vpc_id,
                region_code: peering_conn.accepter_vpc_info.region,
              )

              conn.create_requester_vpc(
                cidr_block: peering_conn.requester_vpc_info.cidr_block,
                owner_id: peering_conn.requester_vpc_info.owner_id,
                vpc_id: peering_conn.requester_vpc_info.vpc_id,
                region_code: peering_conn.requester_vpc_info.region,
              )
            end
          end
        end
      end

      delete_es_docs(es_records_to_delete)
      create_es_docs(es_records_to_update)
    end
  end
end