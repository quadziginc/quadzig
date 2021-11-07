require 'sidekiq_aws_helpers'

class PopulateAwsElasticacheClusterWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_clusters(ec_client)
    clusters = []

    begin
      ec_client.describe_cache_clusters(show_cache_node_info: true).each do |response|
        response.cache_clusters.each do |cluster|
          clusters.append cluster
        end
      end
    rescue Aws::ElastiCache::Errors::AccessDeniedException, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end

    return clusters
  end

  def get_local_existing_clusters(account, aws_region_code)
    return account.aws_elasticache_clusters.where(region_code: aws_region_code).to_a
  end

  def discard_ignored_vpc_clusters(user, clusters)
    user.ignored_aws_vpcs.each do |vpc_id|
      clusters.filter! { |cluster| !(cluster.resources_vpc_config.to_h.fetch(:vpc_id, nil) == vpc_id) }
    end
    return clusters
  end

  def discard_default_vpc_clusters(ec2_client, user, account, clusters)
    temp_vpcs = []
    clusters.each_slice(1000) do |one_k_clusters|
      vpc_ids = one_k_clusters.map { |cluster| cluster.resources_vpc_config.to_h.fetch(:vpc_id, nil) }

      vpc_ids.compact!
      ec2_client.describe_vpcs(vpc_ids: vpc_ids).each do |resp|
        temp_vpcs.concat(resp.vpcs)
      end
    end

    clusters.filter! do |cluster|
      vpc_id = cluster.resources_vpc_config.to_h.fetch(:vpc_id, nil)
      next if vpc_id.nil?

      vpc = temp_vpcs.find { |vpc| vpc.vpc_id == vpc_id }
      if vpc
        !vpc.is_default 
      else
        false
      end
    end
    return clusters
  end

  def get_tags_for_clusters(ec_client, remote_clusters)
    tags = []
    remote_clusters.each do |cluster|
      begin
        tag_list = ec_client.list_tags_for_resource(resource_name: cluster.arn).tag_list
      rescue Aws::ElastiCache::Errors::InvalidReplicationGroupState, Aws::ElastiCache::Errors::CacheClusterNotFound
        next
      end
      tags.append ({
        cluster_arn: cluster.arn,
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
    remote_clusters = get_all_regional_clusters(ec_client)
    return if remote_clusters.nil?

    local_existing_clusters = get_local_existing_clusters(account, aws_region_code)

    remote_clusters = discard_ignored_vpc_clusters(user, remote_clusters)
    if user.ignore_default_vpcs
      remote_clusters = discard_default_vpc_clusters(ec2_client, user, account, remote_clusters)
    end

    remote_cluster_arns = remote_clusters.collect { |cluster| cluster.arn }
    local_existing_cluster_arns = local_existing_clusters.collect { |cluster| cluster.arn }

    cluster_arns_to_destroy = local_existing_cluster_arns - remote_cluster_arns

    es_cluster_records_to_delete = []

    cluster_arns_to_destroy.each do |cluster_arn|
      cluster = local_existing_clusters.detect { |cluster| cluster.arn == cluster_arn }
      if cluster
        es_cluster_records_to_delete.append({
          id: cluster.id,
          routing_key: user.id
        })

        cluster.destroy
        local_existing_clusters.delete_if { |cluster| cluster.arn == cluster_arn }
      end
    end

    cluster_tags = get_tags_for_clusters(ec_client, remote_clusters)

    es_cluster_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_clusters.each do |remote_cluster|
        existing_cluster = account.aws_elasticache_clusters.detect { |cluster| cluster.arn == remote_cluster.arn }

        attributes = {
          cache_cluster_id: remote_cluster.cache_cluster_id,
          configuration_endpoint_address: remote_cluster.try(:configuration_endpoint).try(:address),
          configuration_endpoint_port: remote_cluster.try(:configuration_endpoint).try(:port),
          client_download_landing_page: remote_cluster.client_download_landing_page,
          cache_node_type: remote_cluster.cache_node_type,
          engine: remote_cluster.engine,
          engine_version: remote_cluster.engine_version,
          cache_cluster_status: remote_cluster.cache_cluster_status,
          num_cache_nodes: remote_cluster.num_cache_nodes,
          preferred_availability_zone: remote_cluster.preferred_availability_zone,
          preferred_outpost_arn: remote_cluster.preferred_outpost_arn,
          cache_cluster_create_time: remote_cluster.cache_cluster_create_time,
          preferred_maintenance_window: remote_cluster.preferred_maintenance_window,
          pending_modified_values: remote_cluster.pending_modified_values,
          notification_configuration: remote_cluster.notification_configuration,
          cache_security_groups: remote_cluster.cache_security_groups,
          cache_parameter_group: remote_cluster.cache_parameter_group,
          cache_subnet_group_name: remote_cluster.cache_subnet_group_name,
          auto_minor_version_upgrade: remote_cluster.auto_minor_version_upgrade,
          security_groups: remote_cluster.security_groups,
          replication_group_id: remote_cluster.replication_group_id,
          snapshot_retention_limit: remote_cluster.snapshot_retention_limit,
          snapshot_window: remote_cluster.snapshot_window,
          auth_token_enabled: remote_cluster.auth_token_enabled,
          auth_token_last_modified_date: remote_cluster.auth_token_last_modified_date,
          transit_encryption_enabled: remote_cluster.transit_encryption_enabled,
          at_rest_encryption_enabled: remote_cluster.at_rest_encryption_enabled,
          arn: remote_cluster.arn,
          replication_group_log_delivery_enabled: remote_cluster.try(:replication_group_log_delivery_enabled),
          log_delivery_configurations: remote_cluster.try(:log_delivery_configurations),
          region_code: aws_region_code,
          last_updated_at: DateTime.now,
          tags: (cluster_tags.find { |cluster| cluster[:cluster_arn] == remote_cluster.arn }).to_h.fetch(:tags, nil)
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :elasticache_node,
          [
            :client_download_landing_page,
            :cache_cluster_create_time,
            :pending_modified_values,
            :notification_configuration,
            :cache_security_groups,
            :cache_parameter_group,
            :security_groups,
            :auth_token_last_modified_date,
            :log_delivery_configurations
          ]
        )

        if existing_cluster
          existing_cluster.update(attributes)
          es_cluster_records_to_update.append({
            id: existing_cluster.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        else
          new_cluster = account.aws_elasticache_clusters.create!(attributes)
          es_cluster_records_to_update.append({
            id: new_cluster.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        end

        ec_cluster = existing_cluster ? existing_cluster : new_cluster

        remote_cluster.cache_nodes.each do |cache_node|
          ec_cluster.aws_elasticache_cluster_nodes.create({
            cache_node_id: cache_node.cache_node_id,
            cache_node_status: cache_node.cache_node_status,
            endpoint_address: cache_node.try(:endpoint).try(:address),
            endpoint_port: cache_node.try(:endpoint).try(:port),
            parameter_group_status: cache_node.parameter_group_status,
            source_cache_node_id: cache_node.source_cache_node_id,
            customer_availability_zone: cache_node.customer_availability_zone,
            customer_outpost_arn: cache_node.customer_outpost_arn,
            region_code: aws_region_code,
            last_updated_at: DateTime.now,
            aws_account: account
          })
        end
      end
    end

    delete_es_docs(es_cluster_records_to_delete)
    create_es_docs(es_cluster_records_to_update)
  end
end