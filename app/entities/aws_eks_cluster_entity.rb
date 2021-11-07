class AwsEksClusterEntity < ResourceEntity
  expose :name, expose_nil: false
  expose :arn, expose_nil: false
  expose :cluster_created_at, expose_nil: false
  expose :version, expose_nil: false
  expose :endpoint, expose_nil: false
  expose :role_arn, expose_nil: false
  expose :resources_vpc_config, expose_nil: false
  expose :kubernetes_network_config, expose_nil: false
  expose :logging, expose_nil: false
  expose :identity, expose_nil: false
  expose :status, expose_nil: false
  expose :client_request_token, expose_nil: false
  expose :platform_version, expose_nil: false
  expose :tags, expose_nil: false
  expose :encryption_config, expose_nil: false
end