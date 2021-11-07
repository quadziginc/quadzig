class AwsElbEntity < ResourceEntity
  expose :load_balancer_name, expose_nil: false
  expose :dns_name, expose_nil: false
  expose :vpc_id, expose_nil: false
  expose :canonical_hosted_zone_name, expose_nil: false
  expose :canonical_hosted_zone_name_id, expose_nil: false
  expose :listener_descriptions, expose_nil: false
  expose :policies, expose_nil: false
  expose :backend_server_descriptions, expose_nil: false
  expose :health_check_target, expose_nil: false
  expose :health_check_interval, expose_nil: false
  expose :health_check_timeout, expose_nil: false
  expose :health_check_unhealthy_threshold, expose_nil: false
  expose :health_check_healthy_threshold, expose_nil: false
  expose :source_security_group_owner_alias, expose_nil: false
  expose :source_security_group_group_name, expose_nil: false
  expose :availability_zones
  expose :security_groups
  expose :subnets
  expose :instances
  expose :created_time
  #expose :tags
  expose :scheme
end
