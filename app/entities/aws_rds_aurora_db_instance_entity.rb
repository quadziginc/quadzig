class AwsRdsAuroraDbInstanceEntity < ResourceEntity
  expose :db_instance_identifier
  expose :db_instance_class
  expose :engine
  expose :endpoint_address, expose_nil: false
  expose :allocated_storage
  expose :db_subnet_group_name
  expose :subnet_group_status
  expose :availability_zone
  expose :secondary_availability_zone, expose_nil: false
  expose :multi_az
  expose :engine_version
  expose :auto_minor_version_upgrade
  expose :read_replica_source_db_instance_identifier, expose_nil: false
  expose :replica_mode, expose_nil: false
  expose :iops
  expose :publicly_accessible
  expose :storage_type
  expose :db_cluster_identifier, expose_nil: false
  expose :db_instance_arn
  expose :timezone
  expose :iam_database_authentication_enabled
  expose :performance_insights_enabled
  expose :deletion_protection
  expose :max_allocated_storage, expose_nil: false
  expose :vpc_id
  expose :tag_list, expose_nil: false
end