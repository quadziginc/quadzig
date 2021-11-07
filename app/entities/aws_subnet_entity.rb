class AwsSubnetEntity < ResourceEntity
  expose :availability_zone
  expose :available_ip_address_count
  expose :cidr_block
  expose :default_for_az
  expose :subnet_id
  expose :connectivity_type
  expose :tags, expose_nil: false
end