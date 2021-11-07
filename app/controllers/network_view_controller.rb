class NetworkViewController < ViewsController
  # TODO: Why are we doing this?
  skip_before_action :verify_authenticity_token, only: [:send_share_email]

  def index
    @default_rg = @current_user.resource_groups.where(default: true).first
    unless params["resource_group"]
      redirect_to network_view_path(resource_group: @default_rg.id) and return
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
    elements = Rails.cache.fetch("#{session.id}/network_view/aws_nodes", expires_in: 5.seconds) do
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

  def aws_edges
    elements = []
    @current_user.aws_accounts.each do |account|
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

    render json: elements
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

      label = helpers.get_label_for_resource(vpc, :default_label)
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
            label: label,
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
            label: helpers.get_label_for_resource(igw, :default_label),
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
            label: helpers.get_label_for_resource(ngw, :default_label),
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

        tgw_label = if tgw.view_config['displayLabel'].blank?
          tgw.tags ? tgw.tags.find(-> {{}}) { |t| t["key"] == "Name" }.fetch("value", tgw.tgw_id) : vpc.tgw_id
        else
          tgw.view_config['displayLabel']
        end
        elements << {
          group: 'nodes',
          classes: ['aws-tgw'],
          data: {
            id: helpers.sanitize_for_cytoscape(tgw.id),
            label: tgw_label,
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
end