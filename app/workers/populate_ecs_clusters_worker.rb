require 'sidekiq_aws_helpers'

class PopulateEcsClustersWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers

  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_clusters(ecs)
    cluster_arns = []
    remote_clusters = []
    begin
      ecs.list_clusters.each do |resp|
        cluster_arns.concat resp.cluster_arns
      end
    rescue Aws::ECS::Errors::AccessDeniedException, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      # nil indicates that there was an error while fetching ASGs
      return nil
    end

    cluster_arns.each_slice(100).each do |hundred_clusters|
      resp = ecs.describe_clusters(
        clusters: hundred_clusters,
        include: ["TAGS"]
      )

      remote_clusters.concat resp.clusters
    end

    return remote_clusters
  end

  def get_local_existing_clusters(account, region_code)
    clusters = account.aws_ecs_clusters.where(region_code: region_code)
    return clusters
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

    ecs = Aws::ECS::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    remote_clusters = get_all_regional_clusters(ecs)

    # Exit if there is an issue with fetching
    return if remote_clusters.nil?
    local_existing_clusters = get_local_existing_clusters(account, aws_region_code)

    remote_cluster_arns = remote_clusters.collect { |cluster| cluster.cluster_arn }
    local_cluster_arns = local_existing_clusters.collect { |cluster| cluster.cluster_arn }

    cluster_arns_to_destroy = local_cluster_arns - remote_cluster_arns

    es_records_to_delete = []

    cluster_arns_to_destroy.each do |cluster_arn|
      cluster = local_existing_clusters.detect { |cluster| cluster.cluster_arn == cluster_arn }
      if cluster
        cluster.destroy

        es_records_to_delete.append({
          id: cluster.id,
          routing_key: user.id
        })
      end
    end

    es_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_clusters.each do |remote_cluster|
        existing_cluster = local_existing_clusters.find { |cluster| remote_cluster.cluster_arn == cluster.cluster_arn }
        attributes = {
          cluster_arn: remote_cluster.cluster_arn,
          cluster_name: remote_cluster.cluster_name,
          status: remote_cluster.status,
          registered_container_instances_count: remote_cluster.registered_container_instances_count,
          running_tasks_count: remote_cluster.running_tasks_count,
          pending_tasks_count: remote_cluster.pending_tasks_count,
          active_services_count: remote_cluster.active_services_count,
          capacity_providers: remote_cluster.capacity_providers,
          default_capacity_provider_strategy: remote_cluster.default_capacity_provider_strategy,
          tags: remote_cluster.tags,
          region_code: aws_region_code,
          last_updated_at: DateTime.now
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :ecs_cluster,
          [
            :capacity_providers,
            :default_capacity_provider_strategy
          ]
        )

        if existing_cluster
          existing_cluster.update(attributes)
          es_records_to_update.append({
            id: existing_cluster.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        else
          new_cluster = account.aws_ecs_clusters.create!(attributes)
          es_records_to_update.append({
            id: new_cluster.id,
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