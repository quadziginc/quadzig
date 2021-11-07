require 'sidekiq_aws_helpers'

class PopulateAwsEc2InstancesWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_instances(ec2)
    ec2_instances = []
    begin
      ec2.describe_instances({
        filters: [
          {
            name: "instance-state-name",
            values: ["running"]
          }
        ]
      }).each do |response|
        response.reservations.each do |res|
          res.instances.each do |inst|
            ec2_instances.push inst
          end
        end
      end
    rescue Aws::EC2::Errors::UnauthorizedOperation, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end

    return ec2_instances
  end

  def get_local_existing_regional_instances(account, aws_region_code)
    instances = []
    account.aws_vpcs.each do |vpc|
      vpc.aws_subnets.each do |subnet|
        instances.concat subnet.aws_ec2_instances.where(region_code: aws_region_code)
      end
    end

    return instances
  end

  def discard_ignored_vpc_instances(user, instances)
    user.ignored_aws_vpcs.each do |vpc_id|
      instances.filter! { |inst| !(inst.vpc_id == vpc_id) }
    end
    return instances
  end

  def discard_default_vpc_instances(ec2, instances)
    temp_vpcs = []
    instances.each_slice(1000) do |one_k_instances|
      vpc_ids = one_k_instances.map { |inst| inst.vpc_id }

      # When there are terminated instances, vpc_id is nil
      vpc_ids.compact!
      ec2.describe_vpcs(vpc_ids: vpc_ids).each do |resp|
        temp_vpcs.concat(resp.vpcs)
      end
    end

    instances.filter! do |inst|
      vpc = temp_vpcs.find { |vpc| vpc.vpc_id == inst.vpc_id }
      if vpc
        !vpc.is_default 
      else
        false
      end
    end

    return instances
  end

  def get_security_groups_for_instances(ec2_client, instances)
    security_group_ids = []
    security_groups = []
    security_group_ids = instances.map do |instance|
      instance.security_groups.map { |sg| sg.group_id }
    end

    security_group_ids.flatten!

    security_group_ids.each_slice(1000) do |one_k_sgs|
      ec2_client.describe_security_groups({
        group_ids: one_k_sgs
      }).each do |resp|
        security_groups.concat resp.security_groups
      end
    end

    security_groups
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

    ec2 = Aws::EC2::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    remote_instances = get_all_regional_instances(ec2)
    return if remote_instances.nil?

    local_existing_instances = get_local_existing_regional_instances(account, aws_region_code)
    remote_instances = discard_ignored_vpc_instances(user, remote_instances)
    if user.ignore_default_vpcs
      remote_instances = discard_default_vpc_instances(ec2, remote_instances)
    end

    remote_security_groups = get_security_groups_for_instances(ec2, remote_instances)

    remote_instance_ids = remote_instances.collect { |inst| inst.instance_id }
    local_existing_instance_ids = local_existing_instances.collect { |inst| inst.instance_id }

    # TODO: Figure out the correct deletion process
    instance_ids_to_destroy = local_existing_instance_ids - remote_instance_ids

    es_records_to_delete = []

    instance_ids_to_destroy.each do |instance_id|
      instance = local_existing_instances.detect { |inst| inst.instance_id == instance_id }
      if instance
        instance.destroy
        es_records_to_delete.append({
          id: instance.id,
          routing_key: user.id
        })

        local_existing_instances.delete_if { |inst| inst.instance_id == instance_id }
      end
    end

    es_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_instances.each do |instance|
        subnet = nil
        account.aws_vpcs.each do |vpc|
          vpc.aws_subnets.each do |subn|
            if subn.subnet_id == instance.subnet_id
              subnet = subn
            end
          end
        end

        # TODO: Optimize this
        # If we don't have a local record of subnet yet
        # fail silently and wait for subnet to be discovered
        # This will incur a delay of at least 60 seconds for discovering
        # instances created in new subnets. But that should be fine
        # Maybe we can also signal here that discovery should start for this account
        next unless subnet

        existing_instance = local_existing_instances.detect { |inst| inst.instance_id == instance.instance_id }
        instance_profile_arn = instance.iam_instance_profile ? instance.iam_instance_profile.arn : nil
        instance_profile_id = instance.iam_instance_profile ? instance.iam_instance_profile.id : nil

        sgs_for_this_inst = remote_security_groups.map do |sg|
          AwsEc2SecurityGroup.new({
            description: sg.description,
            group_name: sg.group_name,
            ip_permissions: sg.ip_permissions,
            owner_id: sg.owner_id,
            group_id: sg.group_id,
            ip_permissions_egress: sg.ip_permissions_egress,
            vpc_id: sg.vpc_id,
            region_code: aws_region_code,
            last_updated_at: DateTime.now
          }) if instance.security_groups.map(&:group_id).include? sg.group_id
        end.compact

        attributes = {
          image_id: instance.image_id,
          instance_id: instance.instance_id,
          instance_type: instance.instance_type,
          key_name: instance.key_name,
          launch_time: instance.launch_time,
          platform: instance.platform,
          private_dns_name: instance.private_dns_name,
          private_ip_address: instance.private_ip_address,
          public_dns_name: instance.public_dns_name,
          public_ip_address: instance.public_ip_address,
          state: instance.state.name,
          subnet_id: instance.subnet_id,
          vpc_id: instance.vpc_id,
          architecture: instance.architecture,
          iam_instance_profile_arn: instance_profile_arn,
          iam_instance_profile_id: instance_profile_id,
          region_code: aws_region_code,
          source_dest_check: instance.source_dest_check,
          security_groups: instance.security_groups,
          root_device_type: instance.root_device_type,
          virtualization_type: instance.virtualization_type,
          tags: instance.tags,
          aws_ec2_security_groups: sgs_for_this_inst,
          last_updated_at: DateTime.now
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :ec2_instance,
          [
            :security_groups
          ]
        )

        if existing_instance
          existing_instance.update(attributes)

          es_records_to_update.append({
            id: existing_instance.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        else
          new_instance = account.aws_ec2_instances.create!(attributes.merge(aws_subnet: subnet))
          es_records_to_update.append({
            id: new_instance.id,
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