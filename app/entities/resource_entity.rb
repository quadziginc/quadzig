class ResourceEntity < Grape::Entity
  expose :rt do |instance, options|
    # TODO: This resource_type mapping should be defined in a single location
    if instance.instance_of? AwsTgwAttachment
      resource_type = :tgw_attachment
    elsif instance.instance_of? AwsEcsCluster
      resource_type = :ecs_cluster
    elsif instance.instance_of? AwsVpc
      resource_type = :vpc
    elsif instance.instance_of? AwsTgw
      resource_type = :tgw
    elsif instance.instance_of? AwsSubnet
      resource_type = :subnet
    elsif instance.instance_of? AwsNgw
      resource_type = :ngw
    elsif instance.instance_of? AwsLoadBalancer
      resource_type = :load_balancer
    elsif instance.instance_of? AwsIgw
      resource_type = :igw
    elsif instance.instance_of? AwsEcsService
      resource_type = :ecs_service
    elsif instance.instance_of? AwsEc2Instance
      resource_type = :ec2_instance
    elsif instance.instance_of? AwsRdsDbInstance
      resource_type = :rds_instance
    elsif instance.instance_of? AwsRdsAuroraCluster
      resource_type = :aurora_cluster
    elsif instance.instance_of? AwsPeeringConnection
      resource_type = :peering_connection
    elsif instance.instance_of? AwsRdsAuroraDbInstance
      resource_type = :rds_aurora_instance
    elsif instance.instance_of? AwsEc2Asg
      resource_type = :ec2_asg
    elsif instance.instance_of? AwsElb
      resource_type = :elb
    elsif instance.instance_of? AwsEksCluster
      resource_type = :eks_cluster
    elsif instance.instance_of? AwsEksNodegroup
      resource_type = :eks_nodegroup
    end
  end

  expose :aws_account_id do |instance, options|
    instance.aws_account.account_id
  end
  expose :aws_account_name do |instance, options|
    instance.aws_account.name
  end

  expose :region_code
end
