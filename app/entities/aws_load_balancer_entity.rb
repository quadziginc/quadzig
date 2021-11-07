class AwsLoadBalancerEntity < ResourceEntity
  expose :load_balancer_arn
  expose :dns_name
  expose :load_balancer_name
  expose :scheme
  expose :vpc_id
  expose :state
  expose :lb_type
  expose :ip_address_type
  expose :tags, expose_nil: false
end