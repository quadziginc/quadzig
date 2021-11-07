require 'sidekiq_aws_helpers'

class PopulateAwsElbsWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_elbs(elb_client)
    remote_elbs = []
    begin
      elb_client.describe_load_balancers.each do |resp|
        remote_elbs.concat resp.load_balancer_descriptions
      end
    rescue Aws::ElasticLoadBalancing::Errors::AccessDenied, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end

    remote_elbs
  end

  def get_local_existing_elbs(account, aws_region_code)
    return account.aws_elbs.where(region_code: aws_region_code).to_a
  end

  def discard_ignored_vpc_elbs(user, remote_elbs)
    user.ignored_aws_vpcs.each do |vpc_id|
      remote_elbs.filter! { |lb| !(lb.vpc_id == vpc_id) }
    end

    remote_elbs
  end

  def discard_default_vpc_elbs(user, ec2, remote_elbs)
    temp_vpcs = []
    remote_elbs.each_slice(1000) do |one_k_lbs|
      vpc_ids = one_k_lbs.map { |lb| lb.vpc_id }
      ec2.describe_vpcs(vpc_ids: vpc_ids).each do |resp|
        temp_vpcs.concat(resp.vpcs)
      end
    end

    remote_elbs.filter! do |lb|
      vpc = temp_vpcs.find { |vpc| vpc.vpc_id == lb.vpc_id }
      !vpc.is_default
    end

    remote_elbs
  end

  def get_elb_tags(client, elbs)
    tags = []

    elbs.each_slice(20) do |elbs_slice|
      resp = client.describe_tags({
        load_balancer_names: elbs_slice.map {|elb| elb.load_balancer_name },
      })

      tags.concat(resp.tag_descriptions)
    end

    tags
  end

  def get_security_groups_for_lbs(ec2_client, load_balancers)
    security_group_ids = []
    security_groups = []
    security_group_ids = load_balancers.map do |lb|
      lb.security_groups
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

    elb_client = Aws::ElasticLoadBalancing::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    ec2 = Aws::EC2::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    remote_elbs = get_all_regional_elbs(elb_client)
    return if remote_elbs.nil?
    elb_tags = get_elb_tags(elb_client, remote_elbs)

    local_existing_elbs = get_local_existing_elbs(account, aws_region_code)

    remote_elbs = discard_ignored_vpc_elbs(user, remote_elbs)
    if user.ignore_default_vpcs
      remote_elbs = discard_default_vpc_elbs(user, ec2, remote_elbs)
    end

    remote_security_groups = get_security_groups_for_lbs(ec2, remote_elbs)

    # what has changed?
    remote_elb_names = remote_elbs.collect { |elb| elb.load_balancer_name }
    local_elb_names = local_existing_elbs.collect { |elb| elb.load_balancer_name }

    elb_names_to_destroy = local_elb_names - remote_elb_names

    es_records_to_delete = []

    elb_names_to_destroy.each do |elb_name|
      elb = local_existing_elbs.detect {|elb| elb.load_balancer_name == elb_name }

      next unless elb # skip the loop

      # delete the local db record
      elb.destroy

      # add it to the list of records to be cleared from the elasticsearch
      # routing_key is used to identify the shard
      # https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-routing-field.html
      es_records_to_delete.append({ id: elb.id, routing_key: user.id })
    end

    es_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_elbs.each do |remote_elb|
        existing_elb = local_existing_elbs.find { |elb| remote_elb.load_balancer_name == elb.load_balancer_name }

        sgs_for_this_lb = remote_security_groups.map do |sg|
          AwsElbSecurityGroup.new({
            description: sg.description,
            group_name: sg.group_name,
            ip_permissions: sg.ip_permissions,
            owner_id: sg.owner_id,
            group_id: sg.group_id,
            ip_permissions_egress: sg.ip_permissions_egress,
            vpc_id: sg.vpc_id,
            region_code: aws_region_code,
            last_updated_at: DateTime.now
          }) if remote_elb.security_groups.include? sg.group_id
        end.compact

        attributes = {
          load_balancer_name: remote_elb.load_balancer_name,
          dns_name: remote_elb.dns_name,
          canonical_hosted_zone_name: remote_elb.canonical_hosted_zone_name,
          canonical_hosted_zone_name_id: remote_elb.canonical_hosted_zone_name_id,
          listener_descriptions: remote_elb.listener_descriptions,
          policies: remote_elb.policies,
          backend_server_descriptions: remote_elb.backend_server_descriptions,
          availability_zones: remote_elb.availability_zones,
          security_groups: remote_elb.security_groups,
          subnets: remote_elb.subnets,
          instances: remote_elb.instances.map {|i| i.try(:instance_id) }.compact,
          created_time: remote_elb.created_time,
          tags: elb_tags.find {|t| t.load_balancer_name == remote_elb.load_balancer_name }.try(:tags),
          region_code: aws_region_code,
          scheme: remote_elb.scheme,
          vpc_id: remote_elb.vpc_id,
          aws_account: account,
          last_updated_at: DateTime.now,
          aws_elb_security_groups: sgs_for_this_lb
        }

        if remote_elb.try(:health_check)
          attributes[:health_check_target] = remote_elb.health_check.try(:target)
          attributes[:health_check_interval] = remote_elb.health_check.try(:interval)
          attributes[:health_check_timeout] = remote_elb.health_check.try(:timeout)
          attributes[:health_check_unhealthy_threshold] = remote_elb.health_check.try(:unhealthy_threshold)
          attributes[:health_check_healthy_threshold] = remote_elb.health_check.try(:healthy_threshold)
        end

        if remote_elb.try(:source_security_group)
          attributes[:source_security_group_owner_alias] = remote_elb.source_security_group.try(:owner_alias)
          attributes[:source_security_group_group_name] = remote_elb.source_security_group.try(:group_name)
        end

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :elb, # user searchable keyword in omnisearch
          [   # don't index these attrs in elasticsearch
            :aws_account,
            :availability_zones,
            :security_groups,
            :created_time,
            :listener_descriptions,
            :policies,
            :backend_server_descriptions,
            :instances,
            :aws_lb_security_groups
          ]
        )

        if existing_elb
          existing_elb.update(attributes)
          es_records_to_update.append({
            id: existing_elb.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        else
          new_elb = account.aws_elbs.create!(attributes)
          es_records_to_update.append({
            id: new_elb.id,
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
