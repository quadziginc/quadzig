require 'zip'
require 'csv'

class ExportInfrastructureCsvWorker
  include Sidekiq::Worker

  def delete_csv_and_zip_files(export_id)
    csv_files = Dir.glob("/tmp/#{export_id}*.csv")
    zip_files = Dir.glob("/tmp/#{export_id}*.zip")
    csv_files.each { |f| File.delete(f) }
    zip_files.each { |f| File.delete(f) }
  end

  def create_ec2_csvs(export_id, ec2_resources, user)
    file_name = "#{export_id}-ec2-instances.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Instance ID",
        "Instance Type",
        "Key Name",
        "Platform",
        "Private IP",
        "Public IP",
        "VPC",
        "Subnet",
        "State",
        "Instance Profile ARN",
        "Region",
        "Image ID",
        "Last Updated At(UTC)",
        "Tags"
      ]
      ec2_resources.each do |ec2|
        account = ec2.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          ec2.instance_id,
          ec2.instance_type,
          ec2.key_name,
          ec2.platform,
          ec2.private_ip_address,
          ec2.public_ip_address,
          ec2.vpc_id,
          ec2.subnet_id,
          ec2.state,
          ec2.iam_instance_profile_arn,
          ec2.region_code,
          ec2.image_id,
          ec2.last_updated_at,
          ec2.tags ? ec2.tags.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end

    return file_name
  end

  def create_eks_cluster_csvs(export_id, eks_cluster_resources, user)
    file_name = "#{export_id}-eks-clusters.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Name",
        "Arn",
        "Version",
        "Endpoint",
        "Role Arn",
        "Status",
        "Region Code",
        "Last Updated At(UTC)",
        "Tags"
      ]
      eks_cluster_resources.each do |cluster|
        account = cluster.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          cluster.name,
          cluster.arn,
          cluster.version,
          cluster.endpoint,
          cluster.role_arn,
          cluster.status,
          cluster.region_code,
          cluster.last_updated_at,
          cluster.tags ? cluster.tags.map { |k, v| "#{k} - #{v}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_eks_nodegroup_csvs(export_id, eks_nodegroup_resources, user)
    file_name = "#{export_id}-eks-nodegroups.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "nodegroup_name",
        "nodegroup_arn",
        "Cluster Name",
        "Version",
        "Release Version",
        "Status",
        "Capacity Type",
        "Instance Types",
        "Subnets",
        "Ec2 Ssh Key",
        "Source Security Groups",
        "Ami Type",
        "Node Role",
        "Launch Template Name",
        "Launch Template Id",
        "Launch Template Version",
        "Scaling Min Size",
        "Scaling Max Size",
        "Scaling Desired Size",
        "Disk Size",
        "Region Code",
        "Last Updated At(UTC)",
        "Tags"
      ]
      eks_nodegroup_resources.each do |nodegroup|
        account = nodegroup.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          nodegroup.nodegroup_name,
          nodegroup.nodegroup_arn,
          nodegroup.cluster_name,
          nodegroup.version,
          nodegroup.release_version,
          nodegroup.status,
          nodegroup.capacity_type,
          nodegroup.instance_types,
          nodegroup.subnets,
          nodegroup.ec2_ssh_key,
          nodegroup.source_security_groups,
          nodegroup.ami_type,
          nodegroup.node_role,
          nodegroup.launch_template_name,
          nodegroup.launch_template_id,
          nodegroup.launch_template_version,
          nodegroup.scaling_min_size,
          nodegroup.scaling_max_size,
          nodegroup.scaling_desired_size,
          nodegroup.disk_size,
          nodegroup.region_code,
          nodegroup.last_updated_at,
          nodegroup.tags ? nodegroup.tags.map { |k, v| "#{k} - #{v}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_ec2_asg_csvs(export_id, ec2_asgs, user)
    file_name = "#{export_id}-eks-clusters.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Auto Scaling Group Name",
        "Auto Scaling Group Arn",
        "Launch Configuration Name",
        "Launch Template Id",
        "Launch Template Name",
        "Launch Template Version",
        "Availability Zones",
        "Load Balancer Names",
        "Target Group Arns",
        "Health Check Type",
        "Placement Group",
        "Vpc Zone Identifier",
        "Status",
        "Termination Policies",
        "Service Linked Role Arn",
        "Min Size",
        "Max Size",
        "Desired Capacity",
        "Default Cooldown",
        "Health Check Grace Period",
        "Max Instance Lifetime",
        "New Instances Protected From Scale In",
        "Capacity Rebalance",
        "Region Code",
        "Last Updated At(UTC)",
        "Tags"
      ]
      ec2_asgs.each do |asg|
        account = asg.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          asg.auto_scaling_group_name,
          asg.auto_scaling_group_arn,
          asg.launch_configuration_name,
          asg.launch_template_id,
          asg.launch_template_name,
          asg.launch_template_version,
          asg.availability_zones,
          asg.load_balancer_names,
          asg.target_group_arns,
          asg.health_check_type,
          asg.placement_group,
          asg.vpc_zone_identifier,
          asg.status,
          asg.termination_policies,
          asg.service_linked_role_arn,
          asg.min_size,
          asg.max_size,
          asg.desired_capacity,
          asg.default_cooldown,
          asg.health_check_grace_period,
          asg.max_instance_lifetime,
          asg.new_instances_protected_from_scale_in,
          asg.capacity_rebalance,
          asg.region_code,
          asg.last_updated_at,
          asg.tags ? asg.tags.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_rds_aurora_csvs(export_id, rds_aurora_inst_resources, user)
    file_name = "#{export_id}-rds-aurora-instances.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "DB Instance ID",
        "Instance Type",
        "DB Engine",
        "DB Endpoint",
        "Allocated Storage",
        "Multi AZ",
        "Engine Version",
        "Auto Minor Version Upgrade",
        "IOPs",
        "Publicly Accessible",
        "Storage Type",
        "Cluster ID",
        "IAM Authentication Enabled",
        "Performance Insights Enabled",
        "Deletion Protection",
        "Max Allocated Storage",
        "VPC ID",
        "Region Code",
        "Last Updated At(UTC)",
        "Tags"
      ]
      rds_aurora_inst_resources.each do |db|
        account = db.aws_rds_aurora_cluster.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          db.db_instance_identifier,
          db.db_instance_class,
          db.engine,
          db.endpoint_address,
          db.allocated_storage,
          db.multi_az,
          db.engine_version,
          db.auto_minor_version_upgrade,
          db.iops,
          db.publicly_accessible,
          db.storage_type,
          db.db_cluster_identifier,
          db.iam_database_authentication_enabled,
          db.performance_insights_enabled,
          db.deletion_protection,
          db.max_allocated_storage,
          db.vpc_id,
          db.region_code,
          db.last_updated_at,
          db.tag_list ? db.tag_list.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_lb_csvs(export_id, aws_lb_resources, user)
    file_name = "#{export_id}-load-balancers.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "LB ARN",
        "DNS Name",
        "Created Time",
        "LB Name",
        "Scheme",
        "VPC ID",
        "State",
        "LB Type",
        "Region",
        "IP Address Type",
        "Last Updated At(UTC)",
      ]
      aws_lb_resources.each do |lb|
        account = lb.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          lb.load_balancer_arn,
          lb.dns_name,
          lb.created_time,
          lb.load_balancer_name,
          lb.scheme,
          lb.vpc_id,
          lb.state,
          lb.lb_type,
          lb.region_code,
          lb.ip_address_type,
          lb.last_updated_at,
        ]
      end
    end
    return file_name
  end

  def create_ecs_cluster_csvs(export_id, ecs_cluster_resources, user)
    file_name = "#{export_id}-ecs-clusters.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Cluster ARN",
        "Cluster Name",
        "Status",
        "Container Instance Count",
        "Running Task Count",
        "Pending Tasks Count",
        "Active Services Count",
        "Region",
        "Last Updated At(UTC)",
        "Tags"
      ]
      ecs_cluster_resources.each do |cluster|
        account = cluster.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          cluster.cluster_arn,
          cluster.cluster_name,
          cluster.status,
          cluster.registered_container_instances_count,
          cluster.running_tasks_count,
          cluster.pending_tasks_count,
          cluster.active_services_count,
          cluster.region_code,
          cluster.last_updated_at,
          cluster.tags ? cluster.tags.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_elb_csvs(export_id, elb_resources, user)
    file_name = "#{export_id}-elbs.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Load Balancer Name",
        "DNS Name",
        "VPC ID",
        "Canonical Hosted Zone Name",
        "Canonical Hosted Zone Name ID",
        "Instance Count",
        "Created Time",
        "Region Code",
        "Last Updated At(UTC)",
        "Tags"
      ]
      elb_resources.each do |elb|
        account = elb.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          elb.load_balancer_name,
          elb.dns_name,
          elb.vpc_id,
          elb.canonical_hosted_zone_name,
          elb.canonical_hosted_zone_name_id,
          elb.instances.count,
          elb.created_time,
          elb.region_code,
          elb.last_updated_at,
          elb.tags ? elb.tags.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end


  def create_ecs_service_csvs(export_id, ecs_service_resources, user)
    file_name = "#{export_id}-ecs-services.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Service Arn",
        "Service Name",
        "Cluster Arn",
        "Status",
        "Desired Count",
        "Running Count",
        "Pending Count",
        "Launch Type",
        "Platform Version",
        "Task Definition",
        "Role Arn",
        "Health Check Grace Period Seconds",
        "Scheduling Strategy",
        "Region Code",
        "Last Updated At(UTC)",
        "Tags"
      ]
      ecs_service_resources.each do |service|
        account = service.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          service.service_arn,
          service.service_name,
          service.cluster_arn,
          service.status,
          service.desired_count,
          service.running_count,
          service.pending_count,
          service.launch_type,
          service.platform_version,
          service.task_definition,
          service.role_arn,
          service.health_check_grace_period_seconds,
          service.scheduling_strategy,
          service.region_code,
          service.last_updated_at,
          service.tags ? service.tags.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_rds_mysql_inst_csvs(export_id, rds_mysql_inst_resources, user)
    file_name = "#{export_id}-rds-mysql-instances.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Db Instance Identifier",
        "Db Instance Class",
        "Engine",
        "Endpoint Address",
        "Allocated Storage",
        "Db Subnet Group Name",
        "Subnet Group Status",
        "Multi Az",
        "Engine Version",
        "Auto Minor Version Upgrade",
        "Read Replica Source Db Instance Identifier",
        "Iops",
        "Publicly Accessible",
        "Storage Type",
        "Db Instance Arn",
        "Timezone",
        "Iam Database Authentication Enabled",
        "Performance Insights Enabled",
        "Deletion Protection",
        "Max Allocated Storage",
        "Vpc Id",
        "Region Code",
        "Last Updated At(UTC)",
        "Tag List"
      ]
      rds_mysql_inst_resources.each do |instance|
        account = instance.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          instance.db_instance_identifier,
          instance.db_instance_class,
          instance.engine,
          instance.endpoint_address,
          instance.allocated_storage,
          instance.db_subnet_group_name,
          instance.subnet_group_status,
          instance.multi_az,
          instance.engine_version,
          instance.auto_minor_version_upgrade,
          instance.read_replica_source_db_instance_identifier,
          instance.iops,
          instance.publicly_accessible,
          instance.storage_type,
          instance.db_instance_arn,
          instance.timezone,
          instance.iam_database_authentication_enabled,
          instance.performance_insights_enabled,
          instance.deletion_protection,
          instance.max_allocated_storage,
          instance.vpc_id,
          instance.region_code,
          instance.last_updated_at,
          instance.tag_list ? instance.tag_list.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_rds_postgres_inst_csvs(export_id, rds_postgres_inst_resources, user)
    file_name = "#{export_id}-rds-postgres-instances.csv"
    CSV.open("/tmp/#{file_name}", "wb") do |csv|
      csv << [
        "AWS Account ID",
        "AWS Account Name",
        "Db Instance Identifier",
        "Db Instance Class",
        "Engine",
        "Endpoint Address",
        "Allocated Storage",
        "Db Subnet Group Name",
        "Subnet Group Status",
        "Multi Az",
        "Engine Version",
        "Auto Minor Version Upgrade",
        "Read Replica Source Db Instance Identifier",
        "Iops",
        "Publicly Accessible",
        "Storage Type",
        "Db Instance Arn",
        "Timezone",
        "Iam Database Authentication Enabled",
        "Performance Insights Enabled",
        "Deletion Protection",
        "Max Allocated Storage",
        "Vpc Id",
        "Region Code",
        "Last Updated At(UTC)",
        "Tag List"
      ]
      rds_postgres_inst_resources.each do |instance|
        account = instance.aws_account
        # Let's be extra paranoid
        next unless user.aws_accounts.include? account
        csv << [
          account.account_id,
          account.name,
          instance.db_instance_identifier,
          instance.db_instance_class,
          instance.engine,
          instance.endpoint_address,
          instance.allocated_storage,
          instance.db_subnet_group_name,
          instance.subnet_group_status,
          instance.multi_az,
          instance.engine_version,
          instance.auto_minor_version_upgrade,
          instance.read_replica_source_db_instance_identifier,
          instance.iops,
          instance.publicly_accessible,
          instance.storage_type,
          instance.db_instance_arn,
          instance.timezone,
          instance.iam_database_authentication_enabled,
          instance.performance_insights_enabled,
          instance.deletion_protection,
          instance.max_allocated_storage,
          instance.vpc_id,
          instance.region_code,
          instance.last_updated_at,
          instance.tag_list ? instance.tag_list.map { |e| "#{e['key']} - #{e['value']}" }.join('|') : ''
        ]
      end
    end
    return file_name
  end

  def create_zip_file(export_id, csv_files)
    zipfile_path = "/tmp/#{export_id}.zip"
    zipfile_name = File.basename(zipfile_path)

    Zip::File.open(zipfile_path, Zip::File::CREATE) do |zipfile|
      csv_files.compact.uniq.each do |file_path|
        zipfile.add(file_path, "/tmp/#{file_path}")
      end
    end

    return zipfile_path
  end

  def create_s3_exp_url(zipfile_path, user_id)
    zipfile_name = File.basename(zipfile_path)
    key = "csvs/#{user_id}/#{zipfile_name}"

    s3 = Aws::S3::Client.new(
      region: ENV['AWS_DEFAULT_REGION']
    )

    s3.put_object(
      body: File.open(zipfile_path, "rb"),
      key: key,
      bucket: ENV['SHARE_S3_BUCKET']
    )

    signer = Aws::S3::Presigner.new(client: s3)
    url = signer.presigned_url(
      :get_object,
      bucket: ENV['SHARE_S3_BUCKET'],
      key: key,
      expires_in: 86400
    )

    return url
  end

  def perform(user_id, resource_info)
    user = User.find(user_id)
    grouped_resource_ids = resource_info.group_by { |r| r["nodeType"] }
    export_id = SecureRandom.uuid
    csv_files = []

    # TODO: Add Console link to each of these
    grouped_resource_ids.each do |resource_type, resource_ids|
      ids = resource_info.map { |r| r["id"] }
      # TODO: Define a constants file so that these can be centrally defined
      if resource_type == "ec2instance"
        ec2_resources = AwsEc2Instance.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_ec2_csvs(export_id, ec2_resources, user)
      elsif resource_type == "rdsAuroraInstance"
        rds_aurora_inst_resources = AwsRdsAuroraDbInstance.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_rds_aurora_csvs(export_id, rds_aurora_inst_resources, user)
      elsif resource_type == "awsLb"
        aws_lb_resources = AwsLoadBalancer.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_lb_csvs(export_id, aws_lb_resources, user)
      elsif resource_type == "ecsCluster"
        ecs_cluster_resources = AwsEcsCluster.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_ecs_cluster_csvs(export_id, ecs_cluster_resources, user)
      elsif resource_type == "ecsService"
        ecs_service_resources = AwsEcsService.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_ecs_service_csvs(export_id, ecs_service_resources, user)
      elsif resource_type == "awsElb"
        elb_resources = AwsElb.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_elb_csvs(export_id, elb_resources, user)
      elsif resource_type == "rdsMysqlInstance"
        rds_mysql_inst_resources = AwsRdsDbInstance.where(aws_account: user.aws_accounts, id: ids, engine: 'mysql')
        csv_files.append create_rds_mysql_inst_csvs(export_id, rds_mysql_inst_resources, user)
      elsif resource_type == "rdsPostgresInstance"
        rds_postgres_inst_resources = AwsRdsDbInstance.where(aws_account: user.aws_accounts, id: ids, engine: 'postgres')
        csv_files.append create_rds_postgres_inst_csvs(export_id, rds_postgres_inst_resources, user)
      elsif resource_type == "ec2Asg"
        ec2_asg_resources = AwsEc2Asg.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_ec2_asg_csvs(export_id, ec2_asg_resources, user)
      elsif resource_type == "eksCluster"
        eks_cluster_resources = AwsEksCluster.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_eks_cluster_csvs(export_id, eks_cluster_resources, user)
      elsif resource_type == "eksNodegroup"
        eks_nodegroup_resources = AwsEksNodegroup.where(aws_account: user.aws_accounts, id: ids)
        csv_files.append create_eks_nodegroup_csvs(export_id, eks_nodegroup_resources, user)
      end
    end

    zipfile_path = create_zip_file(export_id, csv_files)
    s3_exp_url = create_s3_exp_url(zipfile_path, user_id)
    delete_csv_and_zip_files(export_id)

    mail = UsersMailer.infrastructure_csv(s3_exp_url.to_s, user.email)
    mail.deliver_later
  end
end
