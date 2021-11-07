class AwsEcsClusterEntity < ResourceEntity
  expose :cluster_arn
  expose :cluster_name
  expose :status
  expose :registered_container_instances_count
  expose :running_tasks_count
  expose :pending_tasks_count
  expose :active_services_count
  expose :tags, expose_nil: false
end