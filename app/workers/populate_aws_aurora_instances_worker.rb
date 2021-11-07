require 'sidekiq_aws_helpers'

class PopulateAwsAuroraInstancesWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  include SecurityGroupAssociateHelper
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_clusters(rds)
    clusters = []

    begin
      rds.describe_db_clusters.each do |response|
        clusters.concat response.db_clusters
      end
    rescue Aws::RDS::Errors::AccessDenied, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end

    return clusters
  end

  def get_local_existing_clusters(account, aws_region_code)
    return account.aws_rds_aurora_clusters.where(region_code: aws_region_code).to_a
  end

  def get_local_existing_instances(clusters, aws_region_code)
    instances = []
    clusters.each do |cluster|
      instances.concat cluster.aws_rds_aurora_db_instances.to_a
    end

    return instances
  end

  def get_all_instances_for_clusters(rds, clusters)
    instances = []
    begin
      clusters.each do |cluster|
        cluster.db_cluster_members.each do |memb|
          rds.describe_db_instances({
            db_instance_identifier: memb.db_instance_identifier
          }).each do |db_resp|
            db_resp.db_instances.each do |inst|
              if inst.db_instance_status == "available"
                instances << inst
              end
            end
          end
        end
      end
    rescue Aws::RDS::Errors::AccessDenied
      return nil
    end

    return instances
  end

  def discard_ignored_vpc_instances(user, instances)
    user.ignored_aws_vpcs.each do |vpc_id|
      instances.filter! { |instance| !(instance.db_subnet_group.vpc_id == vpc_id) }
    end
    return instances
  end

  def discard_default_vpc_instances(user, account, instances)
    account.aws_vpcs.each do |vpc|
      if vpc.is_default
        instances.filter! { |instance| !(instance.db_subnet_group.vpc_id == vpc.vpc_id) }
      end
    end
    return instances
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
    creds = Aws::Credentials.new(access_key, secret_key, session_token)
    rds = Aws::RDS::Client.new(
      region: aws_region_code,
      credentials: creds
    )

    remote_clusters = get_all_regional_clusters(rds)
    return if remote_clusters.nil?
    remote_instances = get_all_instances_for_clusters(rds, remote_clusters)
    return if remote_instances.nil?

    local_existing_clusters = get_local_existing_clusters(account, aws_region_code)
    local_existing_instances = get_local_existing_instances(local_existing_clusters, aws_region_code)

    remote_instances = discard_ignored_vpc_instances(user, remote_instances)
    if user.ignore_default_vpcs
      remote_instances = discard_default_vpc_instances(user, account, remote_instances)
    end

    remote_cluster_arns = remote_clusters.collect { |cluster| cluster.db_cluster_arn }
    remote_instance_arns = remote_instances.collect { |instance| instance.db_instance_arn }

    local_existing_instance_arns = local_existing_instances.collect { |instance| instance.db_instance_arn }
    local_existing_cluster_arns = local_existing_clusters.collect { |cluster| cluster.db_cluster_arn }

    cluster_arns_to_destroy = local_existing_cluster_arns - remote_cluster_arns
    instance_arns_to_destroy = local_existing_instance_arns - remote_instance_arns

    es_instance_records_to_delete = []
    es_cluster_records_to_delete = []

    cluster_arns_to_destroy.each do |cluster_id|
      cluster = local_existing_clusters.detect { |cluster| cluster.db_cluster_arn == cluster_id }
      if cluster
        es_cluster_records_to_delete.append({
          id: cluster.id,
          routing_key: user.id
        })

        cluster.destroy
        local_existing_clusters.delete_if { |cluster| cluster.db_cluster_arn == cluster_id }
      end
    end

    instance_arns_to_destroy.each do |instance_arn|
      instance = local_existing_instances.detect { |instance| instance.db_instance_arn == instance_arn }
      if instance
        es_instance_records_to_delete.append({
          id: instance.id,
          routing_key: user.id
        })

        instance.destroy
        local_existing_instances.delete_if { |instance| instance.db_instance_arn == instance_arn }
      end
    end

    es_cluster_records_to_update = []
    es_db_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_clusters.each do |remote_cluster|
        existing_cluster = account.aws_rds_aurora_clusters.detect { |cluster| cluster.db_cluster_arn == remote_cluster.db_cluster_arn }

        attributes = {
          availability_zones: remote_cluster.availability_zones,
          db_cluster_identifier: remote_cluster.db_cluster_identifier,
          endpoint: remote_cluster.endpoint,
          reader_endpoint: remote_cluster.reader_endpoint,
          multi_az: remote_cluster.multi_az,
          engine: remote_cluster.engine,
          engine_version: remote_cluster.engine_version,
          read_replica_identifiers: remote_cluster.read_replica_identifiers,
          vpc_security_groups: remote_cluster.vpc_security_groups,
          db_cluster_resource_id: remote_cluster.db_cluster_resource_id,
          db_cluster_arn: remote_cluster.db_cluster_arn,
          capacity: remote_cluster.capacity,
          deletion_protection: remote_cluster.deletion_protection,
          tag_list: remote_cluster.tag_list,
          region_code: aws_region_code,
          last_updated_at: DateTime.now
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :aurora_cluster,
          [
            :read_replica_identifiers,
            :vpc_security_groups
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
          new_cluster = account.aws_rds_aurora_clusters.create!(attributes)
          es_cluster_records_to_update.append({
            id: new_cluster.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        end
      end

      remote_instances.each do |remote_instance|
        existing_cluster = account.aws_rds_aurora_clusters.detect { |cluster| cluster.db_cluster_identifier == remote_instance.db_cluster_identifier }
        # Don't create an aurora instance without it's cluster.
        # Will get populated on the next run
        next unless existing_cluster

        existing_db = existing_cluster.aws_rds_aurora_db_instances.detect { |instance| instance.db_instance_identifier == remote_instance.db_instance_identifier }

        attributes = {
          db_instance_identifier: remote_instance.db_instance_identifier,
          db_instance_class: remote_instance.db_instance_class,
          engine: remote_instance.engine,
          endpoint_address: remote_instance.endpoint.address,
          allocated_storage: remote_instance.allocated_storage,
          db_security_groups: remote_instance.db_security_groups,
          vpc_security_groups: remote_instance.vpc_security_groups,
          db_parameter_groups: remote_instance.db_parameter_groups,
          db_subnet_group_name: remote_instance.db_subnet_group.db_subnet_group_name,
          subnet_group_status: remote_instance.db_subnet_group.subnet_group_status,
          subnets: remote_instance.db_subnet_group.subnets,
          availability_zone: remote_instance.availability_zone,
          secondary_availability_zone: remote_instance.secondary_availability_zone,
          multi_az: remote_instance.multi_az,
          engine_version: remote_instance.engine_version,
          auto_minor_version_upgrade: remote_instance.auto_minor_version_upgrade,
          read_replica_source_db_instance_identifier: remote_instance.read_replica_source_db_instance_identifier,
          read_replica_db_instance_identifiers: remote_instance.read_replica_db_instance_identifiers,
          replica_mode: remote_instance.replica_mode,
          iops: remote_instance.iops,
          publicly_accessible: remote_instance.publicly_accessible,
          storage_type: remote_instance.storage_type,
          db_cluster_identifier: remote_instance.db_cluster_identifier,
          db_instance_arn: remote_instance.db_instance_arn,
          timezone: remote_instance.timezone,
          iam_database_authentication_enabled: remote_instance.iam_database_authentication_enabled,
          performance_insights_enabled: remote_instance.performance_insights_enabled,
          deletion_protection: remote_instance.deletion_protection,
          tag_list: remote_instance.tag_list,
          max_allocated_storage: remote_instance.max_allocated_storage,
          vpc_id: remote_instance.db_subnet_group.vpc_id,
          region_code: aws_region_code,
          aws_rds_aurora_cluster: existing_cluster,
          last_updated_at: DateTime.now,
          aws_account: account
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :rds_aurora_instance,
          [
            :aws_rds_aurora_cluster,
            :aws_account,
            :db_security_groups,
            :vpc_security_groups,
            :db_parameter_groups,
            :subnets
          ]
        )

        db_instance = if existing_db
          existing_db.update(attributes)
          existing_db
        else
          existing_cluster.aws_rds_aurora_db_instances.create!(attributes)
        end
        es_db_records_to_update.append({
                                         id: db_instance.id,
                                         attributes: search_attributes,
                                         routing_key: user.id
                                       })
        ec2 = Aws::EC2::Client.new(
          region: aws_region_code,
          credentials: creds
        )

        store_security_groups(client: ec2, resource: db_instance, account: account,
                              groups_ids: db_security_group_ids_for(db_instance), region_code: aws_region_code)
      end
    end

    delete_es_docs(es_instance_records_to_delete)
    delete_es_docs(es_cluster_records_to_delete)

    create_es_docs(es_cluster_records_to_update)
    create_es_docs(es_db_records_to_update)
  end
end