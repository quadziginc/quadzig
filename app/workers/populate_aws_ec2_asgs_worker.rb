require 'sidekiq_aws_helpers'

class PopulateAwsEc2AsgsWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_asgs(asg_client)
    ec2_asgs = []
    begin
      asg_client.describe_auto_scaling_groups({
        max_records: 100
      }).each do |response|
        response.auto_scaling_groups.each do |asg|
          ec2_asgs.push asg
        end
      end
    rescue Aws::AutoScaling::Errors::AccessDenied, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      # nil indicates that there was an error while fetching ASGs
      return nil
    end

    return ec2_asgs
  end

  def get_local_existing_regional_asgs(account, aws_region_code)
    asgs = []
    asgs.concat account.aws_ec2_asgs.where(region_code: aws_region_code).to_a

    return asgs
  end

  def discard_ignored_vpc_asgs(user, account, asgs, ec2_client)
    subnet_ids = asgs.pluck(:vpc_zone_identifier).map { |zi| zi.split(",") }.flatten.compact

    remote_subnets = ec2_client.describe_subnets({filters: [{name: "subnet-id", values: subnet_ids}]}).subnets
    remote_subnets.concat ec2_client.describe_subnets({filters: [{name: "default-for-az", values: ["true"]}]}).subnets

    asgs.filter! do |asg|
      subnet_id = asg.vpc_zone_identifier.split(",").first
      # This means it's a default vpc. TODO: Handle this edge case later
      next(true) if subnet_id.nil?
      subnet = remote_subnets.detect { |sub| sub.subnet_id == subnet_id }
      if subnet
        next !(user.ignored_aws_vpcs.include? subnet.vpc_id)
      end
    end

    return asgs
  end

  def discard_default_vpc_asgs(asg_client, remote_asgs)
    return (remote_asgs.filter! { |asg| asg.vpc_zone_identifier != "" }).to_a
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

    asg_client = Aws::AutoScaling::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    ec2_client = Aws::EC2::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    remote_asgs = get_all_regional_asgs(asg_client)

    #Exit if there is an issue with fetching ASGs
    return if remote_asgs.nil?
    local_existing_asgs = get_local_existing_regional_asgs(account, aws_region_code)

    remote_asgs = discard_ignored_vpc_asgs(user, account, remote_asgs, ec2_client)
    if user.ignore_default_vpcs
      remote_asgs = discard_default_vpc_asgs(asg_client, remote_asgs)
    end

    remote_asg_arns = remote_asgs.collect { |asg| asg.auto_scaling_group_arn }
    local_existing_asg_arns = local_existing_asgs.collect { |asg| asg.auto_scaling_group_arn }

    # TODO: Figure out the correct deletion process
    asg_arns_to_destroy = local_existing_asg_arns - remote_asg_arns

    es_records_to_delete = []

    asg_arns_to_destroy.each do |asg_arn|
      asg = local_existing_asgs.detect { |asg| asg.auto_scaling_group_arn == asg_arn }
      if asg
        asg.destroy
        es_records_to_delete.append({
          id: asg.id,
          routing_key: user.id
        })

        local_existing_asgs.delete_if { |asg| asg.auto_scaling_group_arn == asg_arn }
      end
    end

    es_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_asgs.each do |remote_asg|
        existing_asg = local_existing_asgs.detect { |local_asg| local_asg.auto_scaling_group_arn == remote_asg.auto_scaling_group_arn }
        attributes = {
          auto_scaling_group_name: remote_asg.auto_scaling_group_name,
          auto_scaling_group_arn: remote_asg.auto_scaling_group_arn,
          launch_configuration_name: remote_asg.launch_configuration_name,
          launch_template_id: remote_asg.launch_template.try(:launch_template_id),
          launch_template_name: remote_asg.launch_template.try(:launch_template_name),
          launch_template_version: remote_asg.launch_template.try(:version),
          min_size: remote_asg.min_size,
          max_size: remote_asg.max_size,
          desired_capacity: remote_asg.desired_capacity,
          default_cooldown: remote_asg.default_cooldown,
          availability_zones: remote_asg.availability_zones,
          load_balancer_names: remote_asg.load_balancer_names,
          target_group_arns: remote_asg.target_group_arns,
          health_check_type: remote_asg.health_check_type,
          health_check_grace_period: remote_asg.health_check_grace_period,
          created_time: remote_asg.created_time,
          suspended_processes: remote_asg.suspended_processes,
          placement_group: remote_asg.placement_group,
          vpc_zone_identifier: remote_asg.vpc_zone_identifier,
          enabled_metrics: remote_asg.enabled_metrics,
          status: remote_asg.status,
          tags: remote_asg.tags,
          termination_policies: remote_asg.termination_policies,
          new_instances_protected_from_scale_in: remote_asg.new_instances_protected_from_scale_in,
          service_linked_role_arn: remote_asg.service_linked_role_arn,
          max_instance_lifetime: remote_asg.max_instance_lifetime,
          capacity_rebalance: !!remote_asg.capacity_rebalance,
          region_code: aws_region_code,
          last_updated_at: DateTime.now,
          aws_account: account
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :ec2_asg,
          [
            :suspended_processes,
            :vpc_zone_identifier,
            :enabled_metrics,
            :termination_policies,
            :aws_account
          ]
        )

        instance_attributes = []
        remote_asg.instances.each do |inst|
          instance_attributes << {
            instance_id: inst.instance_id,
            instance_type: inst.instance_type,
            availability_zone: inst.availability_zone,
            lifecycle_state: inst.lifecycle_state,
            health_status: inst.health_status,
            launch_configuration_name: inst.launch_configuration_name,
            launch_template_id: inst.launch_template.try(:launch_template_id),
            launch_template_name: inst.launch_template.try(:launch_template_name),
            launch_template_version: inst.launch_template.try(:version),
            protected_from_scale_in: inst.protected_from_scale_in,
            weighted_capacity: inst.weighted_capacity,
            auto_scaling_group_arn: remote_asg.auto_scaling_group_arn,
            auto_scaling_group_name: remote_asg.auto_scaling_group_name
          }
        end

        if existing_asg
          existing_asg.update(attributes)

          es_records_to_update.append({
            id: existing_asg.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        else
          new_asg = account.aws_ec2_asgs.create!(attributes)

          es_records_to_update.append({
            id: new_asg.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        end

        asg = existing_asg ? existing_asg : new_asg

        # Delete all instances that are not part of current ASG
        instance_ids = instance_attributes.map { |ia| ia[:instance_id] }
        instances_not_part_of_asg_anymore = asg.aws_ec2_asg_instances.where.not(instance_id: instance_ids)
        instances_not_part_of_asg_anymore.destroy_all

        instance_attributes.each do |inst_attr|
          instance = asg.aws_ec2_asg_instances.where(instance_id: inst_attr[:instance_id]).first
          if instance
            instance.update!(inst_attr)
          else
            asg.aws_ec2_asg_instances.create!(inst_attr)
          end
        end
      end
    end

    delete_es_docs(es_records_to_delete)
    create_es_docs(es_records_to_update)
  end
end