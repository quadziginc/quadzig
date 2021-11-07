class AwsEcsServiceEntity < ResourceEntity
  expose :service_arn
  expose :service_name
  expose :cluster_arn
  expose :status
  expose :desired_count
  expose :running_count
  expose :pending_count
  expose :launch_type
  expose :platform_version
  expose :task_definition
  expose :role_arn
  expose :health_check_grace_period_seconds
  expose :enable_ecs_managed_tags
  expose :propagate_tags
  expose :tags, expose_nil: false
end