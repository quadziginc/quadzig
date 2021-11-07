require 'sidekiq_aws_helpers'

class PopulateAwsSubnetsWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  sidekiq_options queue: :discovery, retry: 2, dead: false

  def get_all_regional_subnets(ec2)
    subnets = []

    begin
      ec2.describe_subnets({
        max_results: 1000,
        filters: [{
          name: 'state',
          values: ['available']
        }]
      }).each do |resp|
        subnets.concat(resp.subnets)
      end
    rescue Aws::EC2::Errors::UnauthorizedOperation
      return nil
    end

    return subnets
  end

  def get_all_regional_route_tables(ec2)
    rts = []
    begin
      ec2.describe_route_tables(max_results: 100).each do |resp|
        rts.concat(resp.route_tables)
      end
    rescue Aws::EC2::Errors::UnauthorizedOperation, Aws::Errors::MissingCredentialsError, Aws::Sigv4::Errors::MissingCredentialsError
      return nil
    end
    return rts
  end

  def get_local_existing_subnets(account, aws_region_code)
    existing_subnets = []
    # TODO: N+1 Query? Optimize?
    existing_vpcs = account.aws_vpcs.where(region_code: aws_region_code)
    existing_vpcs.each do |vpc|
      existing_subnets.concat(vpc.aws_subnets)
    end

    return existing_subnets
  end

  def discard_ignored_vpc_subnets(user, subnets)
    user.ignored_aws_vpcs.each do |vpc_id|
      subnets.filter! { |subnet| !(subnet.vpc_id == vpc_id) }
    end
    return subnets
  end

  def discard_default_vpc_subnets(ec2, subnets)
    temp_vpcs = []
    subnets.each_slice(1000) do |one_k_subnets|
      vpc_ids = one_k_subnets.map { |subnet| subnet.vpc_id }
      ec2.describe_vpcs(vpc_ids: vpc_ids).each do |resp|
        temp_vpcs.concat(resp.vpcs)
      end
    end

    subnets.filter! do |subnet|
      vpc = temp_vpcs.find { |vpc| vpc.vpc_id == subnet.vpc_id }
      !vpc.is_default 
    end

    return subnets
  end

  def get_connectivity_type(subnet, rts)
    rt = rts.detect do |r|
      r.associations.pluck(:subnet_id).include? subnet.subnet_id
    end
    # If there is no route table, then it's associated with default route table
    # check if default route table has a route to IGW
    if rt == nil
      vpc_rts = rts.select { |r| r.vpc_id == subnet.vpc_id }
      main_vpc_rt = vpc_rts.detect { |r| r.associations[0] && r.associations[0].main }
      # TODO: Not sure why main_vpc_rt will ever be nil.
      # Try to reproduct. Nil check is just a quickfix
      if main_vpc_rt
        connectivity_type = main_vpc_rt.routes.any? { |route| route.gateway_id.to_s.start_with? "igw" } ? "public" : "private"
      else
        connectivity_type = "private"
      end
    # If it's associated with a non default Route Table
    elsif rt.routes.any? { |route| route.gateway_id.to_s.start_with? "igw" }
      connectivity_type = 'public'
    else
      connectivity_type = 'private'
    end

    return connectivity_type
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

    remote_subnets = get_all_regional_subnets(ec2)
    return if remote_subnets.nil?
    route_tables = get_all_regional_route_tables(ec2)
    return if route_tables.nil?

    local_existing_subnets = get_local_existing_subnets(account, aws_region_code)
    remote_subnets = discard_ignored_vpc_subnets(user, remote_subnets)
    if user.ignore_default_vpcs
      remote_subnets = discard_default_vpc_subnets(ec2, remote_subnets)
    end

    remote_subnet_ids = remote_subnets.collect { |subn| subn.subnet_id }
    local_existing_subnet_ids = local_existing_subnets.collect { |subn| subn.subnet_id }

    subnet_ids_to_destroy = local_existing_subnet_ids - remote_subnet_ids

    es_records_to_delete = []

    # TODO: Optimize?
    subnet_ids_to_destroy.each do |sub_id|
      # TODO: Is this fine? Should this be scoped?
      subnet = local_existing_subnets.detect { |subn| subn.subnet_id == sub_id }
      if subnet
        subnet.destroy
        es_records_to_delete.append({
          id: subnet.id,
          routing_key: user.id
        })
      end
    end

    es_records_to_update = []

    ActiveRecord::Base.transaction do
      remote_subnets.each do |subnet|
        vpc = account.aws_vpcs.where(vpc_id: subnet.vpc_id).first
        next unless vpc
        connectivity_type = get_connectivity_type(subnet, route_tables)
        existing_subnet = vpc.aws_subnets.where(subnet_id: subnet.subnet_id).first
        attributes = {
          availability_zone: subnet.availability_zone,
          available_ip_address_count: subnet.available_ip_address_count,
          cidr_block: subnet.cidr_block,
          default_for_az: subnet.default_for_az,
          subnet_id: subnet.subnet_id,
          last_updated_at: DateTime.now,
          connectivity_type: connectivity_type,
          region_code: aws_region_code,
          tags: subnet.tags
        }

        search_attributes = enrich_attributes(
          attributes.merge(vpc_id: vpc.vpc_id),
          account,
          user,
          :subnet,
          []
        )

        if existing_subnet
          existing_subnet.update(attributes)
          es_records_to_update.append({
            id: existing_subnet.id,
            attributes: search_attributes,
            routing_key: user.id
          })
        else
          new_subnet = account.aws_subnets.create!(attributes.merge(aws_vpc: vpc))
          es_records_to_update.append({
            id: new_subnet.id,
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