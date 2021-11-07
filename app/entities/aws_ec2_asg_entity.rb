class AwsEc2AsgEntity < ResourceEntity
  expose :auto_scaling_group_name
  expose :auto_scaling_group_arn
  expose :launch_configuration_name, expose_nil: false
  expose :launch_template_id, expose_nil: false
  expose :launch_template_name, expose_nil: false
  expose :launch_template_version, expose_nil: false
  expose :min_size
  expose :max_size
  expose :desired_capacity
  expose :default_cooldown
  expose :availability_zones
  expose :load_balancer_names, expose_nil: false
  expose :target_group_arns, expose_nil: false
  expose :health_check_type
  expose :health_check_grace_period
  expose :capacity_rebalance
  expose :placement_group, expose_nil: false
  expose :vpc_zone_identifier
  expose :status, expose_nil: false
  expose :new_instances_protected_from_scale_in
  expose :service_linked_role_arn, expose_nil: false
  expose :max_instance_lifetime, expose_nil: false
  expose :tags
end