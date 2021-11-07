require 'sidekiq_aws_helpers'

class PopulateAwsDbInstancesWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  include SecurityGroupAssociateHelper
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_instances(rds)
    instances = []

    # Aurora instances are populated in a separate job
    begin
      rds.describe_db_instances({
        filters: [
          {
            name: 'engine',
            values: ['postgres', 'mysql']
          }
        ]
      }).each do |response|
        response.db_instances.each do |instance|
          instances << instance if instance.db_instance_status == "available"
        end
      end
    rescue Aws::RDS::Errors::AccessDenied, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end

    return instances
  end

  def get_local_existing_instances(account, aws_region_code)
    return account.aws_rds_db_instances.where(region_code: aws_region_code).to_a
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
    creds = Aws::Credentials.new(access_key, secret_key, session_token)
    rds = Aws::RDS::Client.new(
      region: aws_region_code,
      credentials: creds
    )

    remote_instances = get_all_regional_instances(rds)

    # Exit if there is an issue with fetching
    return if remote_instances.nil?
    local_existing_instances = get_local_existing_instances(account, aws_region_code)

    remote_instances = discard_ignored_vpc_instances(user, remote_instances)
    if user.ignore_default_vpcs
      remote_instances = discard_default_vpc_instances(user, account, remote_instances)
    end

    remote_instance_arns = remote_instances.collect { |instance| instance.db_instance_arn }
    local_existing_instance_arns = local_existing_instances.collect { |instance| instance.db_instance_arn }
    instance_arns_to_destroy = local_existing_instance_arns - remote_instance_arns

    es_records_to_delete = []

    instance_arns_to_destroy.each do |instance_arn|
      instance = local_existing_instances.detect { |instance| instance.db_instance_arn == instance_arn }
      if instance
        instance.destroy
        es_records_to_delete.append({
          id: instance.id,
          routing_key: user.id
        })
        local_existing_instances.delete_if { |instance| instance.db_instance_arn == instance_arn }
      end
    end

    es_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_instances.each do |remote_instance|
        existing_db = account.aws_rds_db_instances.detect { |instance| instance.db_instance_identifier == remote_instance.db_instance_identifier }
        attributes = {
          db_instance_identifier: remote_instance.db_instance_identifier,
          db_instance_class: remote_instance.db_instance_class,
          engine: remote_instance.engine,
          endpoint_address: remote_instance.try(:endpoint).try(:address),
          allocated_storage: remote_instance.allocated_storage,
          db_security_groups: remote_instance.db_security_groups,
          vpc_security_groups: remote_instance.vpc_security_groups,
          db_parameter_groups: remote_instance.db_parameter_groups,
          db_subnet_group_name: remote_instance.try(:db_subnet_group).try(:db_subnet_group_name),
          subnet_group_status: remote_instance.try(:db_subnet_group).try(:subnet_group_status),
          subnets: remote_instance.try(:db_subnet_group).try(:subnets),
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
          vpc_id: remote_instance.try(:db_subnet_group).try(:vpc_id),
          region_code: aws_region_code,
          last_updated_at: DateTime.now
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :rds_instance,
          [
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
                        account.aws_rds_db_instances.create!(attributes)
                      end

        es_records_to_update.append({ id: db_instance.id,
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

    delete_es_docs(es_records_to_delete)
    create_es_docs(es_records_to_update)
  end
end