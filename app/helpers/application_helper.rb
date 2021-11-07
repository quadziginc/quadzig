module ApplicationHelper
  include Pagy::Frontend
  def aws_console_link(resource_type, resource_id, region_code)
    if resource_type.to_sym == :rds_aurora_db_instance
      return "https://console.aws.amazon.com/rds/home?region=#{region_code}#database:id=#{resource_id};is-cluster=false"
    elsif resource_type.to_sym == :rds_db_instance
      return "https://console.aws.amazon.com/rds/home?region=#{region_code}#database:id=#{resource_id};is-cluster=false"
    elsif resource_type.to_sym == :load_balancer
      return "https://console.aws.amazon.com/ec2/v2/home?region=#{region_code}#LoadBalancers:sort=loadBalancerName"
    elsif resource_type.to_sym == :ecs_cluster
      return "https://#{region_code}.console.aws.amazon.com/ecs/home?region=#{region_code}#/clusters/#{resource_id}/services"
    elsif resource_type.to_sym == :ec2_asg
      return "https://#{region_code}.console.aws.amazon.com/ec2autoscaling/home?region=#{region_code}#/details/#{resource_id}?view=details"
    elsif resource_type.to_sym == :elb
      return "https://console.aws.amazon.com/ec2/v2/home?region=#{region_code}#LoadBalancers:search=#{resource_id};sort=dnsName"
    elsif resource_type.to_sym == :eks_cluster
      return "https://console.aws.amazon.com/eks/home?region=#{region_code}#/clusters/#{resource_id}"
    elsif resource_type.to_sym == :vpc
      return "https://console.aws.amazon.com/vpc/home?region=#{region_code}#VpcDetails:VpcId=#{resource_id}"
    elsif resource_type.to_sym == :subnet
      return "https://#{region_code}.console.aws.amazon.com/vpc/home?region=#{region_code}#SubnetDetails:subnetId=#{resource_id}"
    elsif resource_type.to_sym == :ngw
      return "https://#{region_code}.console.aws.amazon.com/vpc/home?region=#{region_code}#NatGatewayDetails:natGatewayId=#{resource_id}"
    elsif resource_type.to_sym == :igw
      return "https://#{region_code}.console.aws.amazon.com/vpc/home?region=#{region_code}#InternetGateway:internetGatewayId=#{resource_id}"
    elsif resource_type.to_sym == :peering_connection
      return "https://console.aws.amazon.com/vpc/home?region=#{region_code}#PeeringConnections:vpcPeeringConnectionId=#{resource_id};sort=vpcPeeringConnectionId"
    elsif resource_type.to_sym == :ec2_instance
      return "https://console.aws.amazon.com/ec2/v2/home?region=#{region_code}#InstanceDetails:instanceId=#{resource_id}"
    elsif resource_type.to_sym == :tgw_attach
      return "https://#{region_code}.console.aws.amazon.com/vpc/home?region=#{region_code}#TransitGatewayAttachments:sort=#{resource_id}"
    elsif resource_type.to_sym == :tgw
      return "https://#{region_code}.console.aws.amazon.com/vpc/home?region=#{region_code}#TransitGateways:transitGatewayId=#{resource_id};sort=transitGatewayId"
    elsif resource_type.to_sym == :rds_aurora_cluster
      return "https://console.aws.amazon.com/rds/home?region=#{region_code}#database:id=#{resource_id};is-cluster=true"
    elsif resource_type.to_sym == :ec2_keypair
      return "https://console.aws.amazon.com/ec2/v2/home?region=#{region_code}#KeyPairs:search=#{resource_id}"
    elsif resource_type.to_sym == :iam_role
      return "https://console.aws.amazon.com/iam/home#/roles/#{resource_id}"
    elsif resource_type.to_sym == :ec2_launch_config
      return "https://console.aws.amazon.com/ec2/v2/home?region=#{region_code}#LaunchConfigurations:launchConfigurationName=#{resource_id}"
    elsif resource_type.to_sym == :ec2_launch_template
      return "https://console.aws.amazon.com/ec2/v2/home?region=#{region_code}#LaunchTemplateDetails:launchTemplateId=#{resource_id}"
    elsif resource_type.to_sym == :ec2_security_group
      return "https://console.aws.amazon.com/ec2/v2/home?region=#{region_code}#SecurityGroup:groupId=#{resource_id}"
    elsif resource_type == :elasticache_rg
      return "https://console.aws.amazon.com/elasticache/home?region=#{region_code}#redis-shards:redis-id=#{resource_id}"
    end
  end

  def eks_nodegroup_link(nodegroup)
    return "https://console.aws.amazon.com/eks/home?region=#{nodegroup.region_code}#/clusters/#{nodegroup.cluster_name}/nodegroups/#{nodegroup.nodegroup_name}"
  end

  def ecs_service_console_link(service)
    cluster_name = service.cluster_arn.split("/")[-1]
    return "https://#{service.region_code}.console.aws.amazon.com/ecs/home?region=#{service.region_code}#/clusters/#{cluster_name}/services/#{service.service_name}/details"
  end

  def elasticache_cluster_console_link(cluster)
    if cluster.engine == "memcached"
      return "https://console.aws.amazon.com/elasticache/home?region=#{cluster.region_code}#memcached-nodes:id=#{cluster.cache_cluster_id};nodes"
    elsif cluster.replication_group_id.nil?
      return "https://console.aws.amazon.com/elasticache/home?region=#{cluster.region_code}#redis-nodes:id=#{cluster.cache_cluster_id};clusters"
    else
      return "https://console.aws.amazon.com/elasticache/home?region=#{cluster.region_code}#redis-shards:redis-id=#{cluster.replication_group_id}"
    end
  end

  def cf_template_console_url(account)
    if !account.cf_stack_id.nil? && !account.cf_region_code.nil?
      region_code = account.cf_region_code
      stack_id = account.cf_stack_id
      return "https://#{region_code}.console.aws.amazon.com/cloudformation/home?region=#{region_code}#/stacks/stackinfo?stackId=#{stack_id}&filteringStatus=active&filteringText=&viewNested=true&hideStacks=false"
    else
      return "https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks?filteringStatus=active&filteringText=Quadzig&viewNested=true&hideStacks=false&stackId="
    end
  end

  def cf_stackset_console_url(account)
    if !account.cf_stack_id.nil? && !account.cf_region_code.nil?
      region_code = account.cf_region_code
      stack_id = account.cf_stack_id
      return "https://#{region_code}.console.aws.amazon.com/cloudformation/home?region=#{region_code}#/stacksets?filteringText=quadzig"
    else
      return "https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacksets?filteringText=quadzig"
    end
  end

  def clickable_aws_console_link(resource_type, resource_id, region)
    link_to(aws_console_link(resource_type, resource_id, region), target: '_blank') do
      content_tag(:p, class: 'mb-0') do
        concat("#{resource_id} ")
        concat(content_tag(:i, nil, class: 'cil-external-link'))
      end
    end
  end

  def breaking_wrap_wrap(txt, col = 80)
    txt.gsub(/(.{1,#{col}})( +|$\n?)|(.{1,#{col}})/,
      "\\1\\3\n") 
  end

  def get_label_for_resource(resource, label_attribute)
    resource.view_config['displayLabel'].blank? ? resource.try(label_attribute) : resource.view_config['displayLabel']
  end

  def render_annotation_for(resource)
    content_tag(:div, class: 'list-group-item', style: 'padding-bottom: 150px') do
      concat(content_tag(:div, class: 'd-flex w-100 justify-content-between') do
        content_tag(:h5, 'Annotation')
      end)
      concat(simple_format(resource.view_config['annotations']))
    end
  end

  def sanitize_for_cytoscape(ident)
    ident.gsub(/[^0-9A-Za-z]/, '')
  end

  def security_groups_with_targets
    @current_user.aws_security_groups.with_source_edges + @current_user.aws_ec2_security_groups.with_source_edges +
      @current_user.aws_lb_security_groups.with_source_edges + @current_user.aws_elb_security_groups.with_source_edges
  end

  def sources_list_for(security_group)
    @current_user.aws_security_groups.where(group_id: security_group.source_edges) +
      @current_user.aws_ec2_security_groups.where(group_id: security_group.source_edges) +
      @current_user.aws_lb_security_groups.where(group_id: security_group.source_edges) +
      @current_user.aws_elb_security_groups.where(group_id: security_group.source_edges)
  end

  def identifier_for(resource, prefix: nil, suffix: nil)
    identifier = resource.id
    sanitize_for_cytoscape(prefix.to_s + identifier + suffix.to_s)
  end
end
