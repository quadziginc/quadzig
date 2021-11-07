require 'sidekiq_aws_helpers'

class VerifyAwsAccountAccessWorker
  include Sidekiq::Worker
  include SidekiqAwsHelpers
  # Approximately 1 Day
  sidekiq_options retry: 10, queue: :accounts

  def verify_iam_access(access_key, secret_key, session_token)
    creds = Aws::Credentials.new(access_key, secret_key, session_token)
    region = AwsRegion.where(region_code: 'us-east-1').first
    # TODO: Figure out if we need to check all regions
    # Disabling temporarily as account verification takes too long
    # AwsRegion.all.each do |region|
      ec2 = Aws::EC2::Client.new(region: region.region_code, credentials: creds)
      ecs = Aws::ECS::Client.new(region: region.region_code, credentials: creds)
      elasticache = Aws::ElastiCache::Client.new(region: region.region_code, credentials: creds)
      elasticloadbalancingv2 = Aws::ElasticLoadBalancingV2::Client.new(region: region.region_code, credentials: creds)
      rds = Aws::RDS::Client.new(region: region.region_code, credentials: creds)
      s3 = Aws::S3::Client.new(region: region.region_code, credentials: creds)


      # TODO: Wrap this in being rescue.
      # Right now, the way we communicate that something went wrong with
      # account creation is by checking from the frontend that the account completion
      # completes within 60 seconds and if it does not, we show a generic error message.
      # Eventually, we would like to show the specific permissions that are missing(if that
      # is the cause of the error).
      # We also need to check that the other API calls are allowed as well(For example: tag based ones)
      # Not sure how to do that yet.

      # TODO: Check all permissions
      # begin

      ec2.describe_addresses
      # ec2.describe_client_vpn_connections
      # ec2.describe_client_vpn_endpoints
      # ec2.describe_client_vpn_routes
      ec2.describe_instances
      ec2.describe_internet_gateways
      ec2.describe_nat_gateways
      ec2.describe_network_acls
      ec2.describe_route_tables
      ec2.describe_security_groups
      # ec2.describe_spot_fleet_instances
      ec2.describe_spot_fleet_requests
      ec2.describe_subnets
      ec2.describe_tags
      ec2.describe_transit_gateway_attachments
      ec2.describe_transit_gateway_peering_attachments
      ec2.describe_transit_gateway_route_tables
      ec2.describe_transit_gateways
      ec2.describe_transit_gateway_vpc_attachments
      ec2.describe_volumes
      ec2.describe_vpc_peering_connections
      ec2.describe_vpcs
      ec2.describe_vpn_connections
      ec2.describe_vpn_gateways
      ecs.describe_clusters
      # ecs.describe_container_instances
      # ecs.describe_services
      ecs.list_clusters
      # ecs.list_container_instances
      # ecs.list_services
      # ecs.list_tags_for_resource
      elasticache.describe_cache_clusters
      # elasticache.describe_cache_subnet_groups
      # elasticache.describe_global_replication_groups
      elasticache.describe_replication_groups
      # elasticache.list_tags_for_resource
      # elasticloadbalancingv2.describe_load_balancer_attributes
      elasticloadbalancingv2.describe_load_balancers
      # elasticloadbalancingv2.describe_tags
      rds.describe_db_clusters
      rds.describe_db_instances
      rds.describe_db_subnet_groups
      # rds.list_tags_for_resource
      # rescue
        # binding.pry
      # end
    # end
  end

  def perform(user_id, account_id)
    access_key, secret_key, session_token = get_aws_iam_credentials(user_id, account_id)

    # TODO: Refactor? Queries are run in the get_aws_iam_credentials method as well
    user = User.find(user_id)
    account = user.aws_accounts.find(account_id)

    asts = Aws::STS::Client.new(
      region: 'us-east-1',
      credentials: Aws::Credentials.new(access_key, secret_key, session_token)
    )

    resp = asts.get_caller_identity
    cust_account_id = resp.account

    # If there are issues with permissions, this method will fail and
    # Account is never marked as complete

    # We will let users decide if they want to provide access to specific resource types
    # So, let's not verify permissions

    # verify_iam_access(access_key, secret_key, session_token)

    account_id_updated = account.update(
      account_id: cust_account_id
    )

    if !account_id_updated && (account.errors.messages[:account_id] == ["has already been taken"])
      account.update(
        account_id: nil,
        status: 'error',
        creation_errors: ["Account with ID #{cust_account_id} already exists! Either delete this AWS Account from Quadzig or delete the existing AWS Account."]
      )
      raise StandardError.new("Account with ID #{cust_account_id} already exists!")
    end

    updated = account.update(
      creation_complete: true,
      status: 'created',
      creation_errors: []
    )

    return unless updated

    # Trigger an immediate sync after account addition
    user.aws_accounts.each do |aws_account|
      aws_account.active_regions.each do |region_code|
        [
          'PopulateAwsVpcsWorker',
          'PopulateAwsSubnetsWorker',
          'PopulateAwsPeeringConnsWorker',
          'PopulateAwsTransitGatewaysWorker',
          'PopulateTgwAttachmentsWorker',
          'PopulateAwsIgwsWorker',
          'PopulateAwsNgwsWorker',
          'PopulateAwsEc2InstancesWorker',
          'PopulateAwsDbInstancesWorker',
          'PopulateAwsAuroraInstancesWorker',
          'PopulateAwsLoadBalancersWorker',
          'PopulateEcsClustersWorker',
          'PopulateAwsEcsServicesWorker',
          'PopulateAwsEc2AsgsWorker',
          'PopulateAwsElbsWorker',
          'PopulateAwsEksResourcesWorker'
        ].each do |worker_class|
          worker_class.constantize.perform_async(user.id, aws_account.id, region_code)
        end
      end
    end
  end
end
