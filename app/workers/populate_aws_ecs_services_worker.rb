require 'sidekiq_aws_helpers'

class PopulateAwsEcsServicesWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  include SecurityGroupAssociateHelper

  sidekiq_options queue: :discovery, retry: 2, dead: false

  # TODO: Slow. Fix it
  def get_all_regional_services(ecs)
    cluster_arns = []
    service_arns = {}
    remote_services = []
    begin
      ecs.list_clusters.each do |resp|
        cluster_arns.concat resp.cluster_arns
      end

      cluster_arns.each do |cluster_arn|
        resp = ecs.list_services(
          cluster: cluster_arn
        )

        service_arns[cluster_arn] = resp.service_arns
      end

      service_arns.each do |cluster_arn, service_arns|
        service_arns.each_slice(10).each do |ten_service_arns|
          resp = ecs.describe_services(
            cluster: cluster_arn,
            services: ten_service_arns,
            include: ["TAGS"]
          )

          remote_services.concat resp.services
        end
      end
    rescue Aws::ECS::Errors::AccessDeniedException, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end

    return remote_services
  end

  def get_local_existing_services(account, region_code)
    services = account.aws_ecs_services.where(region_code: region_code)
    return services
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
    creds = Aws::Credentials.new(access_key, secret_key, session_token)

    ecs = Aws::ECS::Client.new(
      region: aws_region_code,
      credentials: creds
    )

    ec2 = Aws::EC2::Client.new(
      region: aws_region_code,
      credentials: creds
    )

    remote_services = get_all_regional_services(ecs)

    return if remote_services.nil?
    local_existing_services = get_local_existing_services(account, aws_region_code)

    remote_service_arns = remote_services.collect { |service| service.service_arn }
    local_service_arns = local_existing_services.collect { |service| service.service_arn }

    service_arns_to_destroy = local_service_arns - remote_service_arns

    es_records_to_delete = []

    service_arns_to_destroy.each do |service_arn|
      service = local_existing_services.detect { |service| service.service_arn == service_arn }
      if service
        service.destroy
        es_records_to_delete.append({
          id: service.id,
          routing_key: user.id
        })
      end
    end

    es_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_services.each do |remote_service|
        existing_service = local_existing_services.find { |service| remote_service.service_arn == service.service_arn }
        cluster = account.aws_ecs_clusters.find_by(cluster_arn: remote_service.cluster_arn)
        # TODO: Optimize this
        # If the associated cluster is not discovered yet,
        # fail silently and wait for user to trigger a sync again
        # Not optimal. Same strategy is used in ec2 instance discovery as well
        next unless cluster
        attributes = {
          service_arn: remote_service.service_arn,
          service_name: remote_service.service_name,
          cluster_arn: remote_service.cluster_arn,
          load_balancers: remote_service.load_balancers,
          service_registries: remote_service.service_registries,
          status: remote_service.status,
          desired_count: remote_service.desired_count,
          running_count: remote_service.running_count,
          pending_count: remote_service.pending_count,
          launch_type: remote_service.launch_type,
          capacity_provider_strategy: remote_service.capacity_provider_strategy,
          platform_version: remote_service.platform_version,
          task_definition: remote_service.task_definition,
          deployment_configuration: remote_service.deployment_configuration,
          task_sets: remote_service.task_sets,
          deployments: remote_service.deployments,
          role_arn: remote_service.role_arn,
          events: remote_service.events,
          placement_constraints: remote_service.placement_constraints,
          placement_strategy: remote_service.placement_strategy,
          network_configuration: remote_service.network_configuration,
          health_check_grace_period_seconds: remote_service.health_check_grace_period_seconds,
          scheduling_strategy: remote_service.scheduling_strategy,
          deployment_controller: remote_service.deployment_controller,
          enable_ecs_managed_tags: remote_service.enable_ecs_managed_tags,
          propagate_tags: remote_service.propagate_tags,
          tags: remote_service.tags,
          region_code: aws_region_code,
          aws_ecs_cluster: cluster,
          last_updated_at: DateTime.now
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :ecs_service,
          [
            :load_balancers,
            :service_registries,
            :capacity_provider_strategy,
            :deployment_configuration,
            :task_sets,
            :deployments,
            :events,
            :placement_constraints,
            :placement_strategy,
            :network_configuration,
            :scheduling_strategy,
            :aws_ecs_cluster
          ]
        )

        service = if existing_service
                    existing_service.update(attributes)
                    existing_service
                  else
                    account.aws_ecs_services.create!(attributes)
                  end

        es_records_to_update.append({ id: service.id, attributes: search_attributes, routing_key: user.id })
        store_security_groups(client: ec2, resource: service, account: account,
                              groups_ids: service.network_configuration.dig('awsvpc_configuration', 'security_groups'),
                              region_code: aws_region_code)
      end
    end

    delete_es_docs(es_records_to_delete)
    create_es_docs(es_records_to_update)
  end
end