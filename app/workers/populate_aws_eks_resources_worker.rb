require 'sidekiq_aws_helpers'

class PopulateAwsEksResourcesWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_clusters(eks_client)
    clusters = []

    begin
      eks_client.list_clusters.each do |response|
        response.clusters.each do |cluster_name|
          resp = eks_client.describe_cluster(name: cluster_name)
          clusters.append resp.cluster
        end
      end
    rescue Aws::EKS::Errors::AccessDeniedException, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end

    return clusters
  end

  def get_local_existing_clusters(account, aws_region_code)
    return account.aws_eks_clusters.where(region_code: aws_region_code).to_a
  end

  def get_local_existing_nodegroups(clusters, aws_region_code)
    nodegroups = []
    clusters.each do |cluster|
      nodegroups.concat cluster.aws_eks_nodegroups.to_a
    end

    return nodegroups
  end

  def get_all_nodegroups_for_clusters(eks_client, clusters)
    nodegroups = []
    begin
      clusters.each do |cluster|
        eks_client.list_nodegroups(cluster_name: cluster.name).each do |response|
          response.nodegroups.each do |nodegroup_name|
            resp = eks_client.describe_nodegroup({
              cluster_name: cluster.name,
              nodegroup_name: nodegroup_name
            })

            nodegroups.append resp.nodegroup
          end
        end
      end
    rescue Aws::EKS::Errors::AccessDenied
      return nil
    end

    return nodegroups
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

    eks_client = Aws::EKS::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    ec2_client = Aws::EC2::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    # binding.pry if aws_region_code == "us-east-1"

    remote_clusters = get_all_regional_clusters(eks_client)
    return if remote_clusters.nil?
    remote_nodegroups = get_all_nodegroups_for_clusters(eks_client, remote_clusters)
    return if remote_nodegroups.nil?

    local_existing_clusters = get_local_existing_clusters(account, aws_region_code)
    local_existing_nodegroups = get_local_existing_nodegroups(local_existing_clusters, aws_region_code)

    remote_clusters = discard_ignored_vpc_clusters(user, remote_clusters)
    if user.ignore_default_vpcs
      remote_clusters = discard_default_vpc_clusters(ec2_client, user, account, remote_clusters)
    end

    remote_cluster_arns = remote_clusters.collect { |cluster| cluster.arn }
    remote_nodegroup_arns = remote_nodegroups.collect { |nodegroup| nodegroup.nodegroup_arn }

    local_existing_nodegroup_arns = local_existing_nodegroups.collect { |nodegroup| nodegroup.nodegroup_arn }
    local_existing_cluster_arns = local_existing_clusters.collect { |cluster| cluster.arn }

    cluster_arns_to_destroy = local_existing_cluster_arns - remote_cluster_arns
    nodegroup_arns_to_destroy = local_existing_nodegroup_arns - remote_nodegroup_arns

    es_nodegroups_records_to_delete = []
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

    nodegroup_arns_to_destroy.each do |nodegroup_arn|
      nodegroup = local_existing_nodegroups.detect { |nodegroup| nodegroup.nodegroup_arn == nodegroup_arn }
      if nodegroup
        es_nodegroups_records_to_delete.append({
          id: nodegroup.id,
          routing_key: user.id
        })

        nodegroup.destroy
        local_existing_nodegroups.delete_if { |nodegroup| nodegroup.nodegroup_arn == nodegroup_arn }
      end
    end

    es_cluster_records_to_update = []
    es_db_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_clusters.each do |remote_cluster|
        existing_cluster = account.aws_eks_clusters.detect { |cluster| cluster.arn == remote_cluster.arn }

        attributes = {
          name: remote_cluster.name,
          arn: remote_cluster.arn,
          cluster_created_at: remote_cluster.created_at,
          version: remote_cluster.version,
          endpoint: remote_cluster.endpoint,
          role_arn: remote_cluster.role_arn,
          resources_vpc_config: remote_cluster.resources_vpc_config,
          kubernetes_network_config: remote_cluster.kubernetes_network_config,
          logging: remote_cluster.logging,
          identity: remote_cluster.identity,
          status: remote_cluster.status,
          certificate_authority: remote_cluster.certificate_authority,
          client_request_token: remote_cluster.client_request_token,
          platform_version: remote_cluster.platform_version,
          tags: remote_cluster.tags,
          encryption_config: remote_cluster.encryption_config,
          region_code: aws_region_code,
          last_updated_at: DateTime.now
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :eks_cluster,
          [
            :cluster_created_at,
            :resources_vpc_config,
            :kubernetes_network_config,
            :logging,
            :identity,
            :certificate_authority,
            :encryption_config
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
          new_cluster = account.aws_eks_clusters.create!(attributes)
          es_cluster_records_to_update.append({
            id: new_cluster.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        end
      end

      remote_nodegroups.each do |remote_nodegroup|
        existing_cluster = account.aws_eks_clusters.detect { |cluster| cluster.name == remote_nodegroup.cluster_name }

        # Don't create an eks nodegroupo without it's cluster.
        # Will get populated on the next run
        next unless existing_cluster


        existing_nodegroup = existing_cluster.aws_eks_nodegroups.detect { |nodegroup| nodegroup.nodegroup_arn == remote_nodegroup.nodegroup_arn }
        attributes = {
          nodegroup_name: remote_nodegroup.nodegroup_name,
          nodegroup_arn: remote_nodegroup.nodegroup_arn,
          cluster_name: remote_nodegroup.cluster_name,
          version: remote_nodegroup.version,
          release_version: remote_nodegroup.release_version,
          nodegroup_created_at: remote_nodegroup.created_at,
          nodegroup_modified_at: remote_nodegroup.modified_at,
          status: remote_nodegroup.status,
          capacity_type: remote_nodegroup.capacity_type,
          scaling_min_size: remote_nodegroup.scaling_config.min_size,
          scaling_max_size: remote_nodegroup.scaling_config.max_size,
          scaling_desired_size: remote_nodegroup.scaling_config.desired_size,
          instance_types: remote_nodegroup.instance_types,
          subnets: remote_nodegroup.subnets,
          ec2_ssh_key: remote_nodegroup.try(:remote_access).try(:ec2_ssh_key),
          source_security_groups: remote_nodegroup.try(:remote_access).try(:source_security_groups),
          ami_type: remote_nodegroup.ami_type,
          node_role: remote_nodegroup.node_role,
          labels: remote_nodegroup.labels,
          taints: remote_nodegroup.try(:taints),
          resources: remote_nodegroup.resources,
          disk_size: remote_nodegroup.disk_size,
          health: remote_nodegroup.health,
          launch_template_name: remote_nodegroup.try(:launch_template).try(:name),
          launch_template_id: remote_nodegroup.try(:launch_template).try(:id),
          launch_template_version: remote_nodegroup.try(:launch_template).try(:version),
          tags: remote_nodegroup.tags,
          region_code: aws_region_code,
          last_updated_at: DateTime.now,
          aws_account: account,
          aws_eks_cluster: existing_cluster
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :eks_nodegroup,
          [
            :nodegroup_created_at,
            :nodegroup_modified_at,
            :taints,
            :resources,
            :health
          ]
        )

        if existing_nodegroup
          existing_nodegroup.update(attributes)
          es_db_records_to_update.append({
            id: existing_nodegroup.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        else
          new_nodegroup = existing_cluster.aws_eks_nodegroups.create!(attributes)
          es_db_records_to_update.append({
            id: new_nodegroup.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        end
      end
    end

    delete_es_docs(es_nodegroups_records_to_delete)
    delete_es_docs(es_cluster_records_to_delete)

    create_es_docs(es_cluster_records_to_update)
    create_es_docs(es_db_records_to_update)
  end
end