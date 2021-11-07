require 'sidekiq_aws_helpers'

class PopulateAwsElasticacheReplicationGroupsWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_replication_groups(ec_client)
    replication_groups = []

    begin
      ec_client.describe_replication_groups.each do |response|
        response.replication_groups.each do |group|
          replication_groups.append group
        end
      end
    rescue Aws::ElastiCache::Errors::AccessDeniedException, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end

    return replication_groups
  end

  def get_local_existing_replication_groups(account, aws_region_code)
    return account.aws_elasticache_replication_groups.where(region_code: aws_region_code).to_a
  end

  def get_tags_for_rgs(ec_client, remote_replication_groups)
    tags = []
    remote_replication_groups.each do |rg|
      begin
        tag_list = ec_client.list_tags_for_resource(resource_name: rg.arn).tag_list
      rescue Aws::ElastiCache::Errors::InvalidReplicationGroupState, Aws::ElastiCache::Errors::CacheClusterNotFound
        next
      end
      tags.append ({
        rg_arn: rg.arn,
        tags: tag_list
      })
    end

    tags
  end

  def perform(user_id, aws_account_id, aws_region_code)
    user = User.find(user_id)
    account = user.aws_accounts.find(aws_account_id)
    region = AwsRegion.where(region_code: aws_region_code).first

    # Important. Else, sidekiq jobs will pile up
    return unless account.creation_complete

    # TODO: Raise Error on else
    return unless region
    access_key, secret_key, session_token = get_aws_iam_credentials(user_id, aws_account_id)

    # If Aws::Errors::MissingCredentialsError is raised, just exit
    return if access_key.nil?

    ec_client = Aws::ElastiCache::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    ec2_client = Aws::EC2::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    # binding.pry if aws_region_code == "us-east-1"

    remote_replication_groups = get_all_regional_replication_groups(ec_client)
    return if remote_replication_groups.nil?

    local_existing_replication_groups = get_local_existing_replication_groups(account, aws_region_code)

    remote_replication_group_arns = remote_replication_groups.collect { |rg| rg.arn }
    local_existing_replication_group_arns = local_existing_replication_groups.collect { |rg| rg.arn }
    replication_group_arns_to_destroy = local_existing_replication_group_arns - remote_replication_group_arns

    es_rg_records_to_delete = []

    replication_group_arns_to_destroy.each do |rg_arn|
      rg = local_existing_replication_groups.detect { |rg| rg.arn == rg_arn }
      if rg
        es_rg_records_to_delete.append({
          id: rg.id,
          routing_key: user.id
        })

        rg.destroy
        local_existing_replication_groups.delete_if { |rg| rg.arn == rg_arn }
      end
    end

    rg_tags = get_tags_for_rgs(ec_client, remote_replication_groups)

    es_rg_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_replication_groups.each do |replication_group|
        existing_rg = account.aws_elasticache_replication_groups.detect { |rg| rg.arn == replication_group.arn }

        attributes = {
          replication_group_id: replication_group.replication_group_id,
          description: replication_group.description,
          status: replication_group.status,
          pending_modified_values: replication_group.pending_modified_values,
          member_clusters: replication_group.member_clusters,
          snapshotting_cluster_id: replication_group.snapshotting_cluster_id,
          automatic_failover: replication_group.automatic_failover,
          multi_az: replication_group.multi_az,
          configuration_endpoint_address: replication_group.try(:configuration_endpoint).try(:address),
          configuration_endpoint_port: replication_group.try(:configuration_endpoint).try(:port),
          snapshot_retention_limit: replication_group.snapshot_retention_limit,
          snapshot_window: replication_group.snapshot_window,
          cluster_enabled: replication_group.cluster_enabled,
          cache_node_type: replication_group.cache_node_type,
          auth_token_enabled: replication_group.auth_token_enabled,
          auth_token_last_modified_date: replication_group.auth_token_last_modified_date,
          transit_encryption_enabled: replication_group.transit_encryption_enabled,
          at_rest_encryption_enabled: replication_group.at_rest_encryption_enabled,
          member_clusters_outpost_arns: replication_group.member_clusters_outpost_arns,
          kms_key_id: replication_group.kms_key_id,
          arn: replication_group.arn,
          user_group_ids: replication_group.user_group_ids,
          log_delivery_configurations: replication_group.try(:log_delivery_configurations),
          last_updated_at: DateTime.now,
          region_code: aws_region_code,
          tags: (rg_tags.find { |rg| rg[:rg_arn] == replication_group.arn }).to_h.fetch(:tags, nil)
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :elasticache_rg,
          [
            :pending_modified_values,
            :member_clusters,
            :member_clusters_outpost_arns,
            :user_group_ids
          ]
        )

        if existing_rg
          existing_rg.update(attributes)
          es_rg_records_to_update.append({
            id: existing_rg.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        else
          new_rg = account.aws_elasticache_replication_groups.create!(attributes)
          es_rg_records_to_update.append({
            id: new_rg.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        end

        rg = existing_rg ? existing_rg : new_rg
        rg.aws_elasticache_rg_node_groups.destroy_all

        replication_group.node_groups.each do |ng|
          attributes = {
            node_group_id: ng.node_group_id,
            status: ng.status,
            primary_endpoint_address: ng.try(:primary_endpoint).try(:address),
            primary_endpoint_port: ng.try(:primary_endpoint).try(:port),
            reader_endpoint_address: ng.try(:reader_endpoint).try(:address),
            reader_endpoint_port: ng.try(:reader_endpoint).try(:port),
            slots: ng.slots,
            node_group_members: ng.node_group_members,
            aws_account: account,
            last_updated_at: DateTime.now,
            region_code: aws_region_code
          }

          rg.aws_elasticache_rg_node_groups.create!(attributes)
        end
      end
    end

    delete_es_docs(es_rg_records_to_delete)
    create_es_docs(es_rg_records_to_update)
  end
end