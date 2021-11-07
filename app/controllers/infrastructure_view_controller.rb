class InfrastructureViewController < ViewsController
  include ActionView::Helpers::TextHelper
  # TODO: Why are we doing this?
  skip_before_action :verify_authenticity_token, only: [:send_share_email]
  # Calling the same filter multiple times with different options will not work, since the last filter definition will overwrite the previous ones.
  before_action :check_subscription_eligibility!, only: %i[aws_security_groups save_as_new_resource_group],
                                                  if: :method_specific_conditions_satisfied?

  def index
    @default_rg = @current_user.resource_groups.where(default: true).first
    unless params["resource_group"]
      redirect_to infrastructure_view_path(resource_group: @default_rg.id) and return
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

    @accounts = @current_user.aws_accounts

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
    elements = Rails.cache.fetch("#{session.id}/infrastructure_view/aws_nodes", expires_in: 5.seconds) do
      get_nodes_data(resource_group)
    end
    render json: elements
  end

  def export_csv
    # TODO: Move this entire thing to a worker. This will not scale
    resource_ids = export_csv_params["resourceIds"]

    # Convert to simple hash
    resource_ids = resource_ids.map { |r| r.to_h }
    ExportNetworkCsvWorker.perform_async(@current_user.id, resource_ids)
    render body: nil, status: 201
  end

  def save_as_new_resource_group
    nodes_layout = new_rg_params["nodes"].map do |n|
      {
        id: n["data"]["id"],
        position: {
          x: n["position"].class == Array ? n["position"][0]["x"].to_i : n["position"]["x"],
          y: n["position"].class == Array ? n["position"][0]["y"].to_i : n["position"]["y"]
        },
        dimensions: {
          w: n["dimensions"]["w"].to_i,
          h: n["dimensions"]["h"].to_i
        }
      }
    end

    rg = @current_user.resource_groups.create({
      name: new_rg_params["resourceGroupName"]
    })

    rg.display_config["nodes_layout"] = nodes_layout
    rg.display_config["edges"] = new_rg_params["edges"].to_a
    saved = rg.save

    if saved
      render json: {
        status: :ok,
        rgId: rg.id
      }
    else
      render json: {}, status: :bad_request
    end
  end

  def save_current_resource_group
    nodes_layout = current_rg_params["nodes"].map do |n|
      {
        id: n["data"]["id"],
        position: {
          x: n["position"].class == Array ? n["position"][0]["x"].to_i : n["position"]["x"],
          y: n["position"].class == Array ? n["position"][0]["y"].to_i : n["position"]["y"]
        },
        dimensions: {
          w: n["dimensions"]["w"].to_i,
          h: n["dimensions"]["h"].to_i
        }
      }
    end

    rg = @current_user.resource_groups.find(current_rg_params["resourceGroupId"])
    rg.display_config["nodes_layout"] = nodes_layout
    rg.display_config["edges"] = new_rg_params["edges"].to_a
    rg.save
    render json: {status: :ok}
  end

  def delete_resource_group
    resource_group = @current_user.resource_groups.find(params["rg_id"])
    resource_group.destroy!

    @default_rg = @current_user.resource_groups.where(default: true).first
    redirect_to infrastructure_view_path(resource_group: @default_rg.id) and return
  end

  def aws_edges
    elements = []
    exclusion = params[:exclude].split(',')
    @resource_group = @current_user.resource_groups.where(id: params['resource_group']).first

    unless @resource_group.nil?
      @resource_group.display_config["edges"].to_a.each do |edge|
        edge_config = {
          group: 'edges',
          data: {
            id: edge["data"]["id"],
            source: edge["data"]["source"],
            target: edge["data"]["target"],
            edgeType: edge.dig('data', 'edgeType'),
            mirrorEdgeId: edge.dig('data', 'mirrorEdgeId')
          }
        }

        edge["data"]["label"].nil? ? nil : edge_config[:data].merge!({label: edge["data"]["label"]})
        elements << edge_config
      end
    end


    @current_user.aws_accounts.each do |account|
      unless exclusion.include?('peering')
        account.aws_peering_connections.each do |peer_conn|
        source_vpc = account.aws_vpcs.where(vpc_id: peer_conn.accepter_vpc.vpc_id).first
        dest_vpc = account.aws_vpcs.where(vpc_id: peer_conn.requester_vpc.vpc_id).first

        next unless source_vpc && dest_vpc
        elements << {
          group: 'edges',
          classes: ['peering-conn'],
          data: {
            id: helpers.sanitize_for_cytoscape(peer_conn.id),
            source: helpers.sanitize_for_cytoscape(source_vpc.id),
            target: helpers.sanitize_for_cytoscape(dest_vpc.id),
            edgeType: 'peering',
            regionCode: peer_conn.region_code,
            accountId: account.id,
            dbId: peer_conn.id
          }
        }
      end
      end

      unless exclusion.include?('tgwattch')
        account.aws_tgw_attachments.each do |attch|
          elements << {
            group: 'edges',
            classes: ['tgw-attch'],
            data: {
              id: helpers.sanitize_for_cytoscape(attch.id),
              source: helpers.sanitize_for_cytoscape(attch.aws_tgw.id),
              target: helpers.sanitize_for_cytoscape(attch.target_resource.id),
              edgeType: 'tgwattch',
              regionCode: attch.region_code,
              accountId: account.id,
              dbId: attch.id
            }
          }
        end
      end
    end

    unless exclusion.include?('securityGroup')
      if @current_user.subscription_enterprise?
        populate_sg_elements(elements: elements)
      end
    end

    render json: elements
  end

  def aws_security_groups
    render json: populate_sg_elements
  end

  def securityGroup_info
    sg_assoc = case params[:security_group_type] # TODO: get rid of this
               when AwsSecurityGroup.name
                 :aws_security_groups
               when AwsEc2SecurityGroup.name
                 :aws_ec2_security_groups
               when AwsLbSecurityGroup.name
                 :aws_lb_security_groups
               when AwsElbSecurityGroup.name
                 :aws_elb_security_groups
               end

    @sg = @current_user.send(sg_assoc).where(group_id: params[:security_group_id]).first

    render partial: 'info_views/security_group_info'
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
    render partial: "infrastructure_view/ec2_instance_info"
  end

  def rdsAuroraInstance_info
    instance_id = params[:dbId]
    account_id = params[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    instances = account.aws_rds_aurora_clusters.includes(:aws_rds_aurora_db_instances).inject([]) do |insts, cluster|
      insts.concat cluster.aws_rds_aurora_db_instances
    end

    @db = instances.detect { |i| i.id == instance_id }
    render partial: "infrastructure_view/rds_aurora_instance_info"
  end

  def rdsPostgresInstance_info
    instance_id = params[:dbId]
    account_id = params[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    @db = account.aws_rds_db_instances.find(instance_id)
    render partial: "infrastructure_view/rds_instance_info"
  end

  def rdsMysqlInstance_info
    instance_id = params[:dbId]
    account_id = params[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    @db = account.aws_rds_db_instances.find(instance_id)
    render partial: "infrastructure_view/rds_instance_info"
  end

  def lb_info
    lb_id = params[:dbId]
    account_id = params[:account_id]

    account = @current_user.aws_accounts.find(account_id)

    @lb = account.aws_load_balancers.find(lb_id)
    render partial: "infrastructure_view/lb_info"
  end

  def ecsCluster_info
    account_id = params[:account_id]
    cluster_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @cluster = account.aws_ecs_clusters.find(cluster_id)

    render partial: "infrastructure_view/ecs_cluster_info"
  end

  def ecsService_info
    account_id = params[:account_id]
    service_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @service = account.aws_ecs_services.find(service_id)

    primary_deployment = @service.deployments.detect { |d| d["status"] == "PRIMARY" }
    @failed_tasks = primary_deployment ? primary_deployment["failed_tasks"] : 0

    render partial: "infrastructure_view/ecs_service_info"
  end

  def ec2_asg_info
    account_id = params[:account_id]
    asg_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @asg = account.aws_ec2_asgs.find(asg_id)

    render partial: "infrastructure_view/ec2_asg_info"
  end

  def elb_info
    account_id = params[:account_id]
    elb_id = params[:dbId]

    account = @current_user.aws_accounts.find(account_id)
    @elb = account.aws_elbs.find(elb_id)

    render partial: "infrastructure_view/elb_info"
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
    @primary_node_endpoint = "#{@cluster.aws_elasticache_cluster_nodes.first.try(:endpoint_address)}:#{@cluster.aws_elasticache_cluster_nodes.first.try(:endpoint_port)}"

    render partial: "info_views/ec_cluster_info.html.erb"
  end

  def vpc_info
    vpc_id = vpc_info_param[:dbId]
    account_id = vpc_info_param[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    @vpc = account.aws_vpcs.find(vpc_id)
    render status: 404 && return unless @vpc
    render partial: "vpc_info"
  end

  def subnet_info
    subnet_id = subnet_info_param[:subnet_id]
    vpc_id = subnet_info_param[:vpc_id]
    account_id = subnet_info_param[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    vpc = account.aws_vpcs.where(vpc_id: vpc_id).first
    render status: 404 && return unless vpc

    @subnet = vpc.aws_subnets.where(subnet_id: subnet_id).first

    render status: 404 && return unless @subnet
    render partial: "subnet_info"
  end

  def tgw_info
    tgw_id = tgw_info_param[:dbId]
    account_id = igw_info_param[:account_id]

    account = @current_user.aws_accounts.find(account_id)

    @tgw = account.aws_tgws.find(tgw_id)
    render partial: "tgw_info"
  end

  def igw_info
    igw_id = igw_info_param[:dbId]
    account_id = igw_info_param[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    @igw = account.aws_igws.find(igw_id)
    render partial: "igw_info"
  end

  def ngw_info
    ngw_id = ngw_info_param[:dbId]
    account_id = igw_info_param[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    @ngw = account.aws_ngws.find(ngw_id)
    render partial: "ngw_info"
  end

  def peering_info
    peering_id = aws_vpc_peering_info_param[:dbId]
    account_id = aws_vpc_peering_info_param[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    @conn = account.aws_peering_connections.find(peering_id)
    render partial: "peering_info"
  end

  def tgwattch_info
    tgwattch_id = tgwattch_param[:dbId]
    account_id = igw_info_param[:account_id]

    account = @current_user.aws_accounts.find(account_id)
    @attch = account.aws_tgw_attachments.find(tgwattch_id)
    render partial: "tgwattch_info"
  end

  private

  def get_nodes_data(resource_group)
    # The performance of this method is not going to scale
    # we have to pre-populate this data every 60 seconds

    # The dependency on nodeType attribute to call the appropriate method
    # is quite brittle. Switch to a more flexible approach eventually
    elements = []
    instances_part_of_asgs = []
    asgs_part_of_nodegroups = []
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
          dbId: account.id
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
            hoverInfo: "#{region_code} (#{region.full_name})"
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
            dbId: vpc.id
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
              dbId: subnet.id
            }
          }
        end
      end
    end

    AwsEksCluster.where(aws_account: @accounts).includes(:aws_account).each do |cluster|
      hoverInfo = "EKS Service"
      account = cluster.aws_account

      if account.active_regions.include? cluster.region_code
        az_spread_id = SecureRandom.hex
        cluster.aws_eks_nodegroups.each do |nodegroup|
          searchableName = "#{nodegroup.nodegroup_name} - #{account.name} - #{nodegroup.region_code} - EKS Node Group"
          asgs_part_of_nodegroups << ((nodegroup.resources.to_h.fetch("auto_scaling_groups", {}))[0]).to_h.fetch("name", SecureRandom.hex)

          # Used to draw the outline around nodegroups belonging to same cluster
          pair_highlight_id = SecureRandom.hex
          subnets = nodegroup.aws_subnets
          subnets.each do |subnet|
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
                subnetId: subnet.subnet_id,
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
                dbId: nodegroup.id
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
              dbId: asg.id
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
                regionCode: instance.region_code,
                instanceSize: instance.instance_type,
                subnetId: subnet.subnet_id,
                vpcId: instance.vpc_id,
                instanceId: instance.instance_id,
                accountId: account.id,
                hoverInfo: hoverInfo,
                searchableName: searchableName,
                searchableId: instance.id,
                dbId: instance.id
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
                dbId: instance.id
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
              dbId: lb.id
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
              dbId: lb.id
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
              sourceDb: source_db_id
            }
          }
        end
      end
    end

    AwsEcsCluster.where(aws_account: @accounts).includes(:aws_ecs_services).each do |cluster|
      account = cluster.aws_account
      if account.active_regions.include? cluster.region_code
        az_spread_id = SecureRandom.hex
        cluster.aws_ecs_services.each do |service|
          hoverInfo = service.service_name
          searchableName = "#{service.service_name} - #{cluster.cluster_name} - #{account.name} - #{service.region_code} - ECS Service"
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
                dbId: service.id
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
            dbId: igw.id
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
            dbId: ngw.id
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
            dbId: tgw.id
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

  def vpc_info_param
    params.permit(:dbId, :account_id)
  end

  def subnet_info_param
    params.permit(:dbId, :subnet_id, :account_id, :vpc_id)
  end

  def tgw_info_param
    params.permit(:dbId, :account_id)
  end

  def igw_info_param
    params.permit(:dbId, :account_id)
  end

  def ngw_info_param
    params.permit(:dbId, :account_id)
  end

  def aws_vpc_peering_info_param
    params.permit(:dbId, :account_id)
  end

  def tgwattch_param
    params.permit(:dbId, :account_id)
  end

  def export_csv_params
    # TODO: We permit everything. How to fix this?
    params.require(:data).permit!
  end

  def current_rg_params
    params.require(:config).permit!
  end

  def new_rg_params
    params.require(:config).permit!
  end

  def find_sg_resource_for(security_group)
    resource = if security_group.aws_resource.is_a?(AwsEc2Instance)
                 security_group.aws_resource.aws_ec2_asg&.eks_node_group || security_group.aws_resource.aws_ec2_asg
               end
    resource || security_group.aws_resource
  end

  def build_sg_edge_from(source:, target:, sg: )
    {
      group: 'edges',
      classes: ['security-group'],
      data: {
        id: SecureRandom.hex(20),
        edgeType: 'securityGroup',
        source: source,
        target: target,
        sg_id: sg.group_id,
        sg_type: sg.class.name # TODO: get rid of this
      },
    }
  end

  def populate_sg_elements(elements: [])
    helpers.security_groups_with_targets.each do |target_sg|
      helpers.sources_list_for(target_sg).each do |source|
        source_resource = find_sg_resource_for(source)
        target_resource = find_sg_resource_for(target_sg)

        if !source_resource.is_split_across_subnets && !target_resource.is_split_across_subnets
          elements << build_sg_edge_from(source: helpers.sanitize_for_cytoscape(source_resource.id),
                                         target: helpers.sanitize_for_cytoscape(target_resource.id), sg: target_sg)
        end

        if source_resource.is_split_across_subnets && !target_resource.is_split_across_subnets
          source_subnets = source_resource.aws_subnets
          source_subnets.each do |src_subnet|
            elements << build_sg_edge_from(source: helpers.identifier_for(source_resource, prefix: src_subnet.id),
                                           target: helpers.sanitize_for_cytoscape(target_resource.id), sg: target_sg)
          end
        end

        if !source_resource.is_split_across_subnets && target_resource.is_split_across_subnets
          target_subnets = target_resource.aws_subnets
          target_subnets.each do |tg_subnet|
            elements << build_sg_edge_from(source: helpers.sanitize_for_cytoscape(source_resource.id),
                                           target: helpers.identifier_for(target_resource, prefix: tg_subnet.id),
                                           sg: target_sg)
          end
        end

        if source_resource.is_split_across_subnets && target_resource.is_split_across_subnets
          target_subnets = source_resource.aws_subnets
          source_subnets = source_resource.aws_subnets
          target_subnets.each do |tg_subnet|
            source_subnets.each do |src_subnet|
              elements << build_sg_edge_from(source: helpers.identifier_for(source_resource, prefix: src_subnet.id),
                                             target: helpers.identifier_for(target_resource, prefix: tg_subnet.id),
                                             sg: target_sg)
            end
          end
        end
      end
    end
    elements
  end

  def method_specific_conditions_satisfied?
    return @current_user.resource_groups.custom.exists? if action_name == 'save_as_new_resource_group'

    true
  end
end
