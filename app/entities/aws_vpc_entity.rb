class AwsVpcEntity < ResourceEntity
  expose :vpc_id
  expose :is_default
  expose :cidr_block
  expose :tags, expose_nil: false
end