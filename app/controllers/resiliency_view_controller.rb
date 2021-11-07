class ResiliencyViewController < ViewsController
  # TODO: Why are we doing this?
  skip_before_action :verify_authenticity_token, only: [:send_share_email]

  def index
    @default_rg = @current_user.resource_groups.where(default: true).first
    unless params["resource_group"]
      redirect_to resiliency_view_path(resource_group: @default_rg.id) and return
    end
    @resource_group = @current_user.resource_groups.where(id: params["resource_group"]).first
    if @resource_group.nil?
      redirect_to root_path
      return
    end

    @accounts = @current_user.aws_accounts.where(creation_complete: true, role_associated: true)
    if @accounts.empty?
      redirect_to root_path
      return
    end

    if @current_user.subscription.tier.to_s == "free" && @current_user.aws_accounts.where(creation_complete: true).count >= 3
      if !@current_user.in_early_access_period?
        @accounts = @current_user.aws_accounts.where(creation_complete: true).limit(3)
      elsif @current_user.in_early_access_period?
        @accounts = @current_user.aws_accounts.where(creation_complete: true)
      end
    end

    @allowed_ent_aws_account_quantity = @current_user.subscription.aws_account_quantity + 3

    if (@current_user.subscription.tier.to_s == "enterprise" && (@current_user.aws_accounts.where(creation_complete: true).count >= @allowed_ent_aws_account_quantity))
      @accounts = @current_user.aws_accounts.where(creation_complete: true).limit(@allowed_ent_aws_account_quantity)
    end

    region_codes = @accounts.pluck(:active_regions).flatten.uniq
    @regions_for_filter = AwsRegion.where(region_code: region_codes)
  end

  def aws_nodes
    resource_group = @current_user.resource_groups.find(params["resource_group"]) || @current_user.resource_groups.where(default: true).first
    elements = Rails.cache.fetch("#{session.id}/resiliency_view/aws_nodes", expires_in: 5.seconds) do
      get_nodes_data(resource_group)
    end
    render json: elements
  end

  def ec2instance_info
    instance_id = params[:ec2instance_id]
    account_id = params[:account_id]
    vpc_id = params[:vpc_id]
    subnet_id = params[:subnet_id]

    account = @current_user.aws_accounts.find(account_id)
    vpc = account.aws_vpcs.where(vpc_id: vpc_id).first
    subnet = vpc.aws_subnets.where(subnet_id: subnet_id).first

    @ec2 = subnet.aws_ec2_instances.where(instance_id: instance_id).first
    render partial: "ec2_instance_info"
  end

  def rdsAuroraInstance_info
    instance_id = params[:dbId]
    account_id = params[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    instances = account.aws_rds_aurora_clusters.includes(:aws_rds_aurora_db_instances).inject([]) do |insts, cluster|
      insts.concat cluster.aws_rds_aurora_db_instances
    end

    @db = instances.detect { |i| i.id == instance_id }
    render partial: "rds_aurora_instance_info"
  end

  def rdsPostgresInstance_info
    instance_id = params[:dbId]
    account_id = params[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    @db = account.aws_rds_db_instances.find(instance_id)
    render partial: "rds_instance_info"
  end

  def rdsMysqlInstance_info
    instance_id = params[:dbId]
    account_id = params[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    @db = account.aws_rds_db_instances.find(instance_id)
    render partial: "rds_instance_info"
  end

  def lb_info
    lb_id = params[:dbId]
    account_id = params[:account_id]

    account = @current_user.aws_accounts.find(account_id)

    @lb = account.aws_load_balancers.find(lb_id)
    render partial: "lb_info"
  end

  def elb_info
    account_id = params[:account_id]
    elb_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @elb = account.aws_elbs.find(elb_id)

    render partial: "infrastructure_view/elb_info"
  end

  def ecsCluster_info
    account_id = params[:account_id]
    cluster_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @cluster = account.aws_ecs_clusters.find(cluster_id)

    render partial: "ecs_cluster_info"
  end

  def ecsService_info
    account_id = params[:account_id]
    service_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @service = account.aws_ecs_services.find(service_id)

    primary_deployment = @service.deployments.detect { |d| d["status"] == "PRIMARY" }
    @failed_tasks = primary_deployment ? primary_deployment["failed_tasks"] : 0

    render partial: "ecs_service_info"
  end

  def ec2_asg_info
    account_id = params[:account_id]
    asg_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @asg = account.aws_ec2_asgs.find(asg_id)

    render partial: "ec2_asg_info"
  end

  def eksCluster_info
    account_id = params[:account_id]
    cluster_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @cluster = account.aws_eks_clusters.find(cluster_id)

    render partial: "info_views/eks_cluster_info"
  end

  def eksNodegroup_info
    account_id = params[:account_id]
    nodegroup_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @nodegroup = account.aws_eks_nodegroups.find(nodegroup_id)

    render partial: "info_views/eks_nodegroup_info"
  end

  def elasticacheRg_info
    account_id = params[:account_id]
    replication_group_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @rg = account.aws_elasticache_replication_groups.find(replication_group_id)

    render partial: "info_views/ec_rg_info.html.erb"
  end

  def elasticacheCluster_info
    account_id = params[:account_id]
    cluster_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @cluster = account.aws_elasticache_clusters.find(cluster_id)

    render partial: "info_views/ec_cluster_info.html.erb"
  end

  private

  def get_nodes_data(resource_group)
    # The performance of this method is not going to scale
    # we have to pre-populate this data every 60 seconds

    # The dependency on nodeType attribute to call the appropriate method
    # is quite brittle. Switch to a more flexible approach eventually
    elements = []
    asgs_part_of_nodegroups = []
    instances_part_of_asgs = []

    @accounts = @current_user.aws_accounts

    if @current_user.subscription.tier.to_s == "free" && @current_user.aws_accounts.where(creation_complete: true).count >= 3
      if !@current_user.in_early_access_period?
        @accounts = @current_user.aws_accounts.where(creation_complete: true).limit(3)
      end
    end

    @allowed_ent_aws_account_quantity = @current_user.subscription.aws_account_quantity + 3

    if (@current_user.subscription.tier.to_s == "enterprise" && (@current_user.aws_accounts.where(creation_complete: true).count >= @allowed_ent_aws_account_quantity))
      @accounts = @current_user.aws_accounts.where(creation_complete: true).limit(@allowed_ent_aws_account_quantity)
    end

    default_vpc_ids = []
    ignore_default_vpcs = @current_user.ignore_default_vpcs

    all_regions = AwsRegion.all
    all_regions = AwsRegion.all
    @accounts.where(creation_complete: true).each do |account|
      # regions = all_regions.filter { |r| account.active_regions.include? r.region_code }
      hoverInfo = "#{account.name} - #{account.account_id} (AWS Account)"
      elements << {
        group: 'nodes',
        classes: ['aws-account'],
        data: {
          id: account.account_id,
          label: "#{account.name} - #{account.account_id}",
          nodeType: 'account',
          accountId: account.id,
          hoverInfo: hoverInfo,
          searchableName: hoverInfo,
          searchableId: account.account_id,
          dbId: account.id,
          highSeverityIssuesCount: 0,
          mediumSeverityIssuesCount: 0
        }
      }
      account.active_regions.each do |region_code|
        region = all_regions.detect { |r| r.region_code == region_code }
        elements << {
          group: 'nodes',
          classes: ['aws-region'],
          data: {
            id: helpers.sanitize_for_cytoscape("#{account.id}-#{region_code}"),
            label: "#{region_code} (#{region.full_name})",
            parent: account.account_id,
            nodeType: 'region',
            hoverInfo: "#{region_code} (#{region.full_name})",
            highSeverityIssuesCount: 0,
            mediumSeverityIssuesCount: 0
          }
        }
      end
    end

    AwsVpc.where(aws_account: @accounts).includes(:aws_account, aws_subnets: [:aws_ec2_instances]).each do |vpc|
      default_vpc_ids << vpc.vpc_id if vpc.is_default
      next if (ignore_default_vpcs && vpc.is_default)
      if vpc.view_config['displayLabel'].to_s.empty?
        label = vpc.tags ? vpc.tags.find(-> {{}}) { |t| t["key"] == "Name" }.fetch("value", vpc.vpc_id) : vpc.vpc_id
        vpc_label = label + " (#{vpc.cidr_block})"
      else
        vpc_label = vpc.view_config['displayLabel']
      end
      account = vpc.aws_account
      has_subnets = vpc.aws_subnets.any?
      if account.active_regions.include? vpc.region_code
        hoverInfo = "#{label} (VPC)"
        searchableName = "#{label} - #{vpc.vpc_id} - #{account.name} - #{vpc.region_code} - VPC"
        element =  {
          group: 'nodes',
          classes: ['aws-vpc'],
          data: {
            id: helpers.sanitize_for_cytoscape(vpc.id),
            label: vpc_label,
            annotations: vpc.view_config['annotations'],
            parent: helpers.sanitize_for_cytoscape("#{account.id}-#{vpc.region_code}"),
            nodeType: 'vpc',
            regionCode: vpc.region_code,
            accountId: account.id,
            hoverInfo: hoverInfo,
            searchableName: searchableName,
            searchableId: vpc.id,
            dbId: vpc.id,
            highSeverityIssuesCount: 0,
            mediumSeverityIssuesCount: 0
          }
        }
        has_subnets ? element[:classes] << 'parent' : nil
        elements << element

        vpc.aws_subnets.each do |subnet|
          hoverInfo = "#{subnet.cidr_block} (Subnet)"
          searchableName = "#{subnet.subnet_id} - #{account.name} - #{subnet.region_code} - Subnet"
          elements << {
            group: 'nodes',
            classes: subnet.connectivity_type == 'public' ? ['aws-subnet', 'aws-public-subnet'] : ['aws-subnet', 'aws-private-subnet'],
            data: {
              id: helpers.sanitize_for_cytoscape(subnet.id),
              label: helpers.get_label_for_resource(subnet, :cidr_block),
              annotations: subnet.view_config['annotations'],
              parent: helpers.sanitize_for_cytoscape(vpc.id),
              nodeType: 'subnet',
              regionCode: subnet.aws_vpc.region_code,
              accountId: account.id,
              vpcId: vpc.vpc_id,
              subnetId: subnet.subnet_id,
              hoverInfo: hoverInfo,
              searchableName: searchableName,
              searchableId: subnet.id,
              dbId: subnet.id,
              highSeverityIssuesCount: 0,
              mediumSeverityIssuesCount: 0
            }
          }
        end
      end
    end

    AwsEksCluster.where(aws_account: @accounts).includes(:aws_account).each do |cluster|
      hoverInfo = "EKS Service"
      account = cluster.aws_account

      if account.active_regions.include? cluster.region_code
        cluster.aws_eks_nodegroups.each do |nodegroup|
          searchableName = "#{nodegroup.nodegroup_name} - #{account.name} - #{nodegroup.region_code} - EKS Node Group"
          asgs_part_of_nodegroups << ((nodegroup.resources.to_h.fetch("auto_scaling_groups", {}))[0]).to_h.fetch("name", SecureRandom.hex)

          # Used to draw the outline around nodegroups belonging to same cluster
          az_spread_id = SecureRandom.hex

          subnets = nodegroup.aws_subnets
          subnets.each do |subnet|
            pair_highlight_id = SecureRandom.hex
            elements << {
              group: 'nodes',
              classes: ['aws-eks-nodegroup'],
              data: {
                id: helpers.sanitize_for_cytoscape("#{subnet.id}-#{nodegroup.id}"),
                label: helpers.get_label_for_resource(nodegroup, :nodegroup_name),
                annotations: nodegroup.view_config['annotations'],
                parent: helpers.sanitize_for_cytoscape(subnet.id),
                nodeType: 'eksNodegroup',
                azSpreadId: az_spread_id,
                isSpreadAcrossSubnets: true,
                pairHighlightId: pair_highlight_id,
                nodegroupName: nodegroup.nodegroup_name,
                clusterName: nodegroup.cluster_name,
                desiredCount: nodegroup.scaling_desired_size,
                regionCode: nodegroup.region_code,
                accountId: account.id,
                hoverInfo: "#{nodegroup.nodegroup_name} Node Group",
                searchableName: searchableName,
                searchableId: nodegroup.id,
                dbId: nodegroup.id,
                highSeverityIssuesCount: nodegroup.high_severity_issues.count,
                mediumSeverityIssuesCount: nodegroup.medium_severity_issues.count
              }
            }
          end
        end
      end
    end


    # IMPORTANT!: This block of ASG should be BEFORE the block that populates EC2 instances
    # This is because we don't want to show EC2 Instances that are already part of the ASG

    # IMPORTANT!: This block of ASG should be AFTER the block that populates EKS Nodegroups
    # This is because we don't want to show ASGs that are already part of the Nodegroups

    # Populate an array of instances that will later be used to remove instances that are already
    # part of the ASG from the visualization
    AwsEc2Asg.where(aws_account: @accounts).includes(:aws_account).each do |asg|
      next if asg.desired_capacity == 0 # Don't show empty ASGs
      # TODO: VPC ID is not populated yet. Add this as an attribute to asg eventually
      # next if (ignore_default_vpcs && (default_vpc_ids.include? lb.vpc_id))
      account = asg.aws_account
      instances_part_of_asgs.concat asg.aws_ec2_asg_instances.pluck(:instance_id)

      # IMPORTANT: This statement should appear after the instances_part_of_asgs is populated
      next if asgs_part_of_nodegroups.include? asg.auto_scaling_group_name
      hoverInfo = "EC2 Service"
      # TODO: This will probably create duplicate elements in the elements array.
      # Fix this later.
      if account.active_regions.include? asg.region_code
        searchableName = "#{asg.auto_scaling_group_name} - #{account.name} - #{asg.region_code} - Auto Scaling Group"

        az_spread_id = SecureRandom.hex
        pair_highlight_id = SecureRandom.hex
        subnets = asg.aws_subnets
        subnets.each do |subnet|
          elements << {
            group: 'nodes',
            classes: ['aws-ec2-asg'],
            data: {
              id: helpers.sanitize_for_cytoscape("#{subnet.id}-#{asg.id}"),
              label: helpers.get_label_for_resource(asg, :auto_scaling_group_name),
              annotations: asg.view_config['annotations'],
              desiredCapacity: asg.desired_capacity,
              parent: helpers.sanitize_for_cytoscape(subnet.id),
              nodeType: 'ec2Asg',
              asgArn: asg.auto_scaling_group_arn,
              isSpreadAcrossSubnets: true,
              azSpreadId: az_spread_id,
              subnetId: subnet.subnet_id,
              pairHighlightId: pair_highlight_id,
              regionCode: asg.region_code,
              accountId: account.id,
              hoverInfo: "#{asg.auto_scaling_group_name} ASG",
              searchableName: searchableName,
              searchableId: asg.id,
              dbId: asg.id,
              highSeverityIssuesCount: asg.high_severity_issues.count,
              mediumSeverityIssuesCount: asg.medium_severity_issues.count
            }
          }
        end
      end
    end

    AwsVpc.where(aws_account: @accounts).includes(:aws_account, aws_subnets: [:aws_ec2_instances]).each do |vpc|
      default_vpc_ids << vpc.vpc_id if vpc.is_default
      next if (ignore_default_vpcs && vpc.is_default)

      label = vpc.tags ? vpc.tags.find(-> {{}}) { |t| t["key"] == "Name" }.fetch("value", vpc.vpc_id) : vpc.vpc_id
      account = vpc.aws_account
      has_subnets = vpc.aws_subnets.any?
      # TODO: Directly query resources instead of going through vpc
      if account.active_regions.include? vpc.region_code
        vpc.aws_subnets.each do |subnet|
          subnet.aws_ec2_instances.each do |instance|
            next if instances_part_of_asgs.include? instance.instance_id
            if instance.tags && instance.tags.detect { |t| t['key'] == 'Name' }
              tag =  instance.tags.detect { |t| t['key'] == 'Name' }
              label = tag.fetch("value", instance.instance_id)
              hoverInfo = "#{label} (EC2 Instance)"
              searchableName = "#{label} - #{instance.instance_id} - #{account.name} - #{instance.region_code} - EC2 Instance"
            else
              label = instance.instance_id
              hoverInfo = "#{instance.instance_id} (EC2 Instance)"
              searchableName = "#{instance.instance_id} - #{account.name} - #{instance.region_code} - EC2 Instance"
            end

            if !instance.view_config['displayLabel'].to_s.empty?
              label = instance.view_config['displayLabel']
            end

            elements << {
              group: 'nodes',
              classes: ['aws-ec2-instance'],
              data: {
                id: helpers.sanitize_for_cytoscape(instance.id),
                label: label,
                annotations: instance.view_config['annotations'],
                parent: helpers.sanitize_for_cytoscape(subnet.id),
                nodeType: 'ec2instance',
                instanceId: instance.instance_id,
                regionCode: instance.region_code,
                instanceSize: instance.instance_type,
                subnetId: subnet.subnet_id,
                vpcId: instance.vpc_id,
                accountId: account.id,
                hoverInfo: hoverInfo,
                searchableName: searchableName,
                searchableId: instance.id,
                dbId: instance.id,
                highSeverityIssuesCount: instance.high_severity_issues.count,
                mediumSeverityIssuesCount: instance.medium_severity_issues.count
              }
            }
          end
        end
      end
    end

    # We will not show clusters for now. Because clusters can be
    # cross region/cross zonal
    AwsRdsAuroraCluster.where(aws_account: @accounts).includes(:aws_account, :aws_rds_aurora_db_instances).each do |cluster|
      account = cluster.aws_account
      if account.active_regions.include? cluster.region_code
        az_spread_id = SecureRandom.hex
        cluster.aws_rds_aurora_db_instances.each do |instance|
          next if (ignore_default_vpcs && (default_vpc_ids.include? instance.vpc_id))
          vpc = account.aws_vpcs.where(vpc_id: instance.vpc_id).first
          if vpc
            subnet_id = instance.subnets.filter { |s| s["subnet_availability_zone"]["name"] == instance.availability_zone }.first["subnet_identifier"]
            subnet = account.aws_subnets.where(subnet_id: subnet_id).first

            # TODO: Fix this later. If the subnet is not populated yet, we skip visualizing the RDS instance
            # In this case, multiple syncs are required to visualize the DB
            next unless subnet

            searchableName = "#{instance.db_instance_identifier} - #{account.name} - #{instance.region_code} - RDS Aurora Instance"
            elements << {
              group: 'nodes',
              classes: ['aws-rds-instance', 'aws-aurora-db-instance'],
              data: {
                id: helpers.sanitize_for_cytoscape(instance.id),
                label: helpers.get_label_for_resource(instance, :db_instance_identifier),
                annotations: instance.view_config['annotations'],
                parent: helpers.sanitize_for_cytoscape(subnet.id),
                nodeType: 'rdsAuroraInstance',
                azSpreadId: az_spread_id,
                regionCode: instance.region_code,
                accountId: account.id,
                vpcId: instance.vpc_id,
                subnetId: subnet_id,
                hoverInfo: "#{instance.db_instance_identifier} (Aurora DB)",
                searchableName: searchableName,
                searchableId: instance.id,
                dbId: instance.id,
                highSeverityIssuesCount: instance.high_severity_issues.count,
                mediumSeverityIssuesCount: instance.medium_severity_issues.count
              }
            }
          end
        end
      end
    end

    AwsElb.where(aws_account: @accounts).includes(:aws_account).each do |lb|
      next if (ignore_default_vpcs && (default_vpc_ids.include? lb.vpc_id))
      account = lb.aws_account
      vpc = account.aws_vpcs.where(vpc_id: lb.vpc_id).first
      next unless vpc

      account = lb.aws_account
      if account.active_regions.include? lb.region_code
        searchableName = "#{lb.load_balancer_name} - #{account.name} - #{lb.region_code} - ELB"
        elements << {
          group: 'nodes',
            classes: ['aws-elb'],
            data: {
              id: helpers.sanitize_for_cytoscape(lb.id),
              label: helpers.get_label_for_resource(lb, :load_balancer_name),
              annotations: lb.view_config['annotations'],
              parent: helpers.sanitize_for_cytoscape(vpc.id),
              nodeType: 'awsElb',
              consoleFilter: lb.load_balancer_name,
              regionCode: lb.region_code,
              accountId: account.id,
              vpcId: lb.vpc_id,
              hoverInfo: "#{lb.load_balancer_name} (ELB)",
              searchableName: searchableName,
              searchableId: lb.id,
              dbId: lb.id,
              highSeverityIssuesCount: lb.high_severity_issues.count,
              mediumSeverityIssuesCount: lb.medium_severity_issues.count
            }
        }
      end
    end

    AwsLoadBalancer.where(aws_account: @accounts).includes(:aws_account).each do |lb|
      next if (ignore_default_vpcs && (default_vpc_ids.include? lb.vpc_id))
      account = lb.aws_account
      vpc = account.aws_vpcs.where(vpc_id: lb.vpc_id).first
      next unless vpc
      if account.active_regions.include? lb.region_code
        searchableName = "#{lb.load_balancer_name} - #{account.name} - #{lb.region_code} - #{lb.lb_type.camelcase} LB"
        class_name = "aws-#{lb.lb_type}-lb"
        elements << {
          group: 'nodes',
            classes: ['aws-lb', class_name],
            data: {
              id: helpers.sanitize_for_cytoscape(lb.id),
              label: helpers.get_label_for_resource(lb, :load_balancer_name),
              annotations: lb.view_config['annotations'],
              parent: helpers.sanitize_for_cytoscape(vpc.id),
              nodeType: 'awsLb',
              regionCode: lb.region_code,
              accountId: account.id,
              vpcId: lb.vpc_id,
              hoverInfo: "#{lb.load_balancer_name} (#{lb.lb_type.camelcase} LB)",
              searchableName: searchableName,
              searchableId: lb.id,
              dbId: lb.id,
              highSeverityIssuesCount: lb.high_severity_issues.count,
              mediumSeverityIssuesCount: lb.medium_severity_issues.count
            }
        }
      end
    end

    db_instances = AwsRdsDbInstance.where(aws_account: @accounts).includes(:aws_account)
    db_instances.each do |instance|
      account = instance.aws_account
      next if (ignore_default_vpcs && (default_vpc_ids.include? instance.vpc_id))
      node_type = instance.engine == "mysql" ? "rdsMysqlInstance" : "rdsPostgresInstance"
      vpc = account.aws_vpcs.where(vpc_id: instance.vpc_id).first
      account = instance.aws_account
      if account.active_regions.include? instance.region_code
        # We do not support db block lists yet
        if vpc
          subnet_id = instance.subnets.filter { |s| s["subnet_availability_zone"]["name"] == instance.availability_zone }.first["subnet_identifier"]
          subnet = account.aws_subnets.where(subnet_id: subnet_id).first
          searchableName = "#{instance.db_instance_identifier} - #{account.name} - #{instance.region_code} - RDS Instance"
          is_replica = !instance.read_replica_source_db_instance_identifier.nil?
          if is_replica
            source_db = db_instances.where(region_code: instance.region_code, db_instance_identifier: instance.read_replica_source_db_instance_identifier).first
            source_db_id = source_db ? helpers.sanitize_for_cytoscape(source_db.db_instance_arn) : SecureRandom.hex
          else
            # Non existent source
            source_db_id = SecureRandom.hex
          end

          # TODO: Parent attribute will probably fail for some cases
          # Add more error checking
          elements << {
            group: 'nodes',
            classes: ['aws-rds-instance', 'aws-db-instance'],
            data: {
              id: helpers.sanitize_for_cytoscape(instance.id),
              label: helpers.get_label_for_resource(instance, :db_instance_identifier),
              annotations: instance.view_config['annotations'],
              parent: helpers.sanitize_for_cytoscape(subnet.id),
              nodeType: node_type,
              regionCode: instance.region_code,
              accountId: account.id,
              vpcId: instance.vpc_id,
              subnetId: subnet_id,
              hoverInfo: "#{instance.db_instance_identifier} (RDS DB)",
              searchableName: searchableName,
              searchableId: instance.id,
              dbId: instance.id,
              isReplica: is_replica,
              sourceDb: source_db_id,
              highSeverityIssuesCount: instance.high_severity_issues.count,
              mediumSeverityIssuesCount: instance.medium_severity_issues.count
            }
          }
        end
      end
    end

    AwsEcsCluster.where(aws_account: @accounts).includes(:aws_ecs_services).each do |cluster|
      account = cluster.aws_account
      if account.active_regions.include? cluster.region_code

        searchableName = "#{cluster.cluster_name} - #{account.name} - #{cluster.region_code} - ECS Cluster"
        # elements << {
        #   group: 'nodes',
        #   classes: ['aws-ecs-cluster'],
        #   data: {
        #     id: cluster.cluster_arn,
        #     label: cluster.cluster_name,
        #     parent: "#{account.id}-#{cluster.region_code}-ecs",
        #     nodeType: 'ecsCluster',
        #     regionCode: cluster.region_code,
        #     accountId: account.id,
        #     hoverInfo: cluster.cluster_name,
        #     clusterName: cluster.cluster_name,
        #     searchableName: searchableName,
        #     searchableId: cluster.id,
        #     dbId: cluster.id
        #   }
        # }

        az_spread_id = SecureRandom.hex
        cluster.aws_ecs_services.each do |service|
          hoverInfo = service.service_name
          searchableName = "#{service.service_name} - #{cluster.cluster_name} - #{account.name} - #{service.region_code} - ECS Service"
          # TODO: Some services dont have subnets. Why?
          subnets = account.aws_subnets.where(subnet_id: service.network_configuration.to_h.fetch('awsvpc_configuration', {}).fetch('subnets', []))

          pair_highlight_id = SecureRandom.hex
          subnets.each do |subnet|
            elements << {
              group: 'nodes',
              classes: ['aws-ecs-service'],
              data: {
                id: helpers.sanitize_for_cytoscape("#{subnet.id}-#{service.id}"),
                label: helpers.get_label_for_resource(service, :service_name),
                annotations: service.view_config['annotations'],
                parent: helpers.sanitize_for_cytoscape(subnet.id),
                nodeType: 'ecsService',
                azSpreadId: az_spread_id,
                isSpreadAcrossSubnets: true,
                subnetId: subnet.subnet_id,
                pairHighlightId: pair_highlight_id,
                regionCode: service.region_code,
                accountId: account.id,
                hoverInfo: hoverInfo,
                clusterName: cluster.cluster_name,
                serviceName: service.service_name,
                searchableName: "#{service.service_name} (ECS Service)",
                searchableId: service.id,
                dbId: service.id,
                highSeverityIssuesCount: service.high_severity_issues.count,
                mediumSeverityIssuesCount: service.medium_severity_issues.count
              }
            }
          end
        end
      end
    end

    AwsIgw.where(aws_account: @accounts).includes(:aws_account).each do |igw|
      next if (ignore_default_vpcs && (default_vpc_ids.include? igw.vpc_id))
      account = igw.aws_account
      vpc = account.aws_vpcs.where(vpc_id: igw.vpc_id).first
      next unless vpc

      if account.active_regions.include? igw.region_code
        hoverInfo = "#{igw.igw_id} IGW"
        searchableName = "#{igw.igw_id} - #{account.name} - #{igw.region_code} - Internet Gateway"
        elements << {
          group: 'nodes',
          classes: ['aws-igw'],
          data: {
            id: helpers.sanitize_for_cytoscape(igw.id),
            label: igw.view_config['displayLabel'].to_s.empty? ? 'IGW' : igw.view_config['displayLabel'],
            annotations: igw.view_config['annotations'],
            parent: helpers.sanitize_for_cytoscape(vpc.id),
            nodeType: 'igw',
            regionCode: igw.region_code,
            accountId: account.id,
            hoverInfo: hoverInfo,
            searchableName: searchableName,
            searchableId: igw.id,
            dbId: igw.id,
            highSeverityIssuesCount: 0,
            mediumSeverityIssuesCount: 0
          }
        }
      end
    end

    AwsNgw.where(aws_account: @accounts).includes(:aws_account).each do |ngw|
      next if (ignore_default_vpcs && (default_vpc_ids.include? ngw.vpc_id))
      account = ngw.aws_account

      subnet = account.aws_subnets.where(subnet_id: ngw.subnet_id).first
      next unless subnet
      if account.active_regions.include? ngw.region_code
        hoverInfo = "#{ngw.ngw_id} (NGW)"
        searchableName = "#{ngw.ngw_id} - #{account.name} - #{ngw.region_code} - NAT Gateway"
        elements << {
          group: 'nodes',
          classes: ['aws-ngw'],
          data: {
            id: ngw.ngw_id,
            id: helpers.sanitize_for_cytoscape(ngw.id),
            label: ngw.view_config['displayLabel'].to_s.empty? ? 'NGW' : ngw.view_config['displayLabel'],
            annotations: ngw.view_config['annotations'],
            parent: helpers.sanitize_for_cytoscape(subnet.id),
            nodeType: 'ngw',
            regionCode: ngw.region_code,
            accountId: account.id,
            hoverInfo: hoverInfo,
            searchableName: searchableName,
            searchableId: ngw.id,
            dbId: ngw.id,
            highSeverityIssuesCount: 0,
            mediumSeverityIssuesCount: 0
          }
        }
      end
    end

    AwsTgw.where(aws_account: @accounts).includes(:aws_account).each do |tgw|
      account = tgw.aws_account
      if account.active_regions.include? tgw.region_code
        hoverInfo = "#{tgw.tgw_id} (TGW)"
        searchableName = "#{tgw.tgw_id} - #{account.name} - #{tgw.region_code} - Transit Gateway"

        if tgw.view_config['displayLabel'].to_s.empty?
          tgw_label = tgw.tags ? tgw.tags.find(-> {{}}) { |t| t["key"] == "Name" }.fetch("value", tgw.tgw_id) : vpc.tgw_id
        else
          tgw_label = tgw.view_config['displayLabel']
        end
        elements << {
          group: 'nodes',
          classes: ['aws-tgw'],
          data: {
            id: helpers.sanitize_for_cytoscape(tgw.id),
            label: tgw_label,
            annotations: tgw.view_config['annotations'],
            parent: helpers.sanitize_for_cytoscape("#{account.id}-#{tgw.region_code}"),
            nodeType: 'tgw',
            regionCode: tgw.region_code,
            accountId: account.id,
            hoverInfo: hoverInfo,
            searchableName: searchableName,
            searchableId: tgw.id,
            dbId: tgw.id,
            highSeverityIssuesCount: 0,
            mediumSeverityIssuesCount: 0
          }
        }
      end
    end

    @resource_group = @current_user.resource_groups.where(id: params["resource_group"]).first
    unless @resource_group.nil?
      @resource_group.display_config["edges"].to_a.each do |edge|
        edge_config = {
          group: 'edges',
          data: {
            id: edge["data"]["id"],
            source: edge["data"]["source"],
            target: edge["data"]["target"]
          }
        }

        edge["data"]["label"].nil? ? nil : edge_config[:data].merge!({
          label: edge["data"]["label"]
        })
        elements << edge_config
      end
    end

    # TODO: Expensive operation. See if it can be optimized
    nodes_layout = resource_group.display_config["nodes_layout"]

    # Remove any element that user had manually removed and saved
    elements.reject! { |ele| !(nodes_layout.pluck("id").include? ele[:data][:id]) } if nodes_layout
    elements.each do |ele|
      unless nodes_layout.nil?
        node_config = nodes_layout.find { |p| p["id"] == ele[:data][:id] }
        if node_config
          ele[:position] = node_config["position"],
          ele[:style] = {
            width: node_config["dimensions"]["w"],
            height: node_config["dimensions"]["h"],
          }
        end
      end
      # If the element is a parent
      # if ele[:data][:parent] == nil
      children = elements.filter { |e| e[:data][:parent] == ele[:data][:id] }
      # If it has only one child
      if children.length == 1
        child = children[0]
        grand_children = elements.filter { |e| e[:data][:parent] == child[:data][:id] }
        # If the child is an end node/does not have children of it's own
        if grand_children.length == 0
          child[:classes] << 'single-end-child'
        end
      end
    end

    return {
      elements: elements,
      display_config: resource_group.display_config
    }
  end
end
