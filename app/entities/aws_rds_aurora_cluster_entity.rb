class AwsRdsAuroraClusterEntity < ResourceEntity
  expose :db_cluster_identifier
  expose :endpoint
  expose :reader_endpoint, expose_nil: false
  expose :multi_az
  expose :engine
  expose :engine_version
  expose :db_cluster_resource_id, expose_nil: false
  expose :db_cluster_arn, expose_nil: false
  expose :capacity
  expose :deletion_protection
  expose :tag_list, expose_nil: false
end