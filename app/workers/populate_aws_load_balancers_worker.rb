require 'sidekiq_aws_helpers'

class PopulateAwsLoadBalancersWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_lbs(lbc)
    remote_lbs = []
    begin
      lbc.describe_load_balancers.each do |resp|
        remote_lbs.concat resp.load_balancers
      end
    rescue Aws::ElasticLoadBalancingV2::Errors::AccessDenied, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end
    return remote_lbs
  end

  def get_local_existing_lbs(account, aws_region_code)
    return account.aws_load_balancers.where(region_code: aws_region_code).to_a
  end

  def discard_ignored_vpc_lbs(user, remote_lbs)
    user.ignored_aws_vpcs.each do |vpc_id|
      remote_lbs.filter! { |lb| !(lb.vpc_id == vpc_id) }
    end
    return remote_lbs
  end

  def discard_default_vpc_lbs(user, ec2, remote_lbs)
    temp_vpcs = []
    remote_lbs.each_slice(1000) do |one_k_lbs|
      vpc_ids = one_k_lbs.map { |lb| lb.vpc_id }
      ec2.describe_vpcs(vpc_ids: vpc_ids).each do |resp|
        temp_vpcs.concat(resp.vpcs)
      end
    end

    remote_lbs.filter! do |lb|
      vpc = temp_vpcs.find { |vpc| vpc.vpc_id == lb.vpc_id }
      !vpc.is_default 
    end

    return remote_lbs
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

    lbc = Aws::ElasticLoadBalancingV2::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    ec2 = Aws::EC2::Client.new(
      region: aws_region_code,
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    remote_lbs = get_all_regional_lbs(lbc)
    return if remote_lbs.nil?

    local_existing_lbs = get_local_existing_lbs(account, aws_region_code)

    remote_lbs = discard_ignored_vpc_lbs(user, remote_lbs)
    if user.ignore_default_vpcs
      remote_lbs = discard_default_vpc_lbs(user, ec2, remote_lbs)
    end

    remote_security_groups = get_security_groups_for_lbs(ec2, remote_lbs)

    remote_lb_arns = remote_lbs.collect { |lb| lb.load_balancer_arn }
    local_lb_arns = local_existing_lbs.collect { |lb| lb.load_balancer_arn }

    lb_arns_to_destroy = local_lb_arns - remote_lb_arns

    es_records_to_delete = []

    lb_arns_to_destroy.each do |lb_arn|
      lb = local_existing_lbs.detect { |lb| lb.load_balancer_arn == lb_arn }
      if lb
        lb.destroy
        es_records_to_delete.append({
          id: lb.id,
          routing_key: user.id
        })
      end
    end

    es_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_lbs.each do |remote_lb|
        existing_lb = local_existing_lbs.find { |lb| remote_lb.load_balancer_arn == lb.load_balancer_arn }

        sgs_for_this_lb = remote_security_groups.map do |sg|
          AwsLbSecurityGroup.new({
            description: sg.description,
            group_name: sg.group_name,
            ip_permissions: sg.ip_permissions,
            owner_id: sg.owner_id,
            group_id: sg.group_id,
            ip_permissions_egress: sg.ip_permissions_egress,
            vpc_id: sg.vpc_id,
            region_code: aws_region_code,
            last_updated_at: DateTime.now
          }) if remote_lb.security_groups.include? sg.group_id
        end.compact

        attributes = {
          load_balancer_arn: remote_lb.load_balancer_arn,
          dns_name: remote_lb.dns_name,
          created_time: remote_lb.created_time,
          load_balancer_name: remote_lb.load_balancer_name,
          scheme: remote_lb.scheme,
          vpc_id: remote_lb.vpc_id,
          state: remote_lb.state.code,
          lb_type: remote_lb.type,
          availability_zones: remote_lb.availability_zones,
          security_groups: remote_lb.security_groups,
          region_code: aws_region_code,
          aws_account: account,
          ip_address_type: remote_lb.ip_address_type,
          last_updated_at: DateTime.now,
          aws_lb_security_groups: sgs_for_this_lb,
        }

        search_attributes = enrich_attributes(
          attributes,
          account,
          user,
          :load_balancer,
          [
            :aws_account,
            :availability_zones,
            :security_groups,
            :aws_lb_security_groups
          ]
        )

        if existing_lb
          existing_lb.update(attributes)
          es_records_to_update.append({
            id: existing_lb.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        else
          new_lb = account.aws_load_balancers.create!(attributes)
          es_records_to_update.append({
            id: new_lb.id,
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