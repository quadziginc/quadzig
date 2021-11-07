class AwsEc2InstanceEntity < ResourceEntity
  expose :image_id
  expose :instance_id
  expose :instance_type
  expose :key_name, expose_nil: false
  expose :launch_time
  expose :platform, expose_nil: false
  expose :private_dns_name, expose_nil: false
  expose :private_ip_address, expose_nil: false
  expose :public_dns_name, expose_nil: false
  expose :public_ip_address, expose_nil: false
  expose :state
  expose :subnet_id
  expose :vpc_id
  expose :architecture
  expose :iam_instance_profile_arn, expose_nil: false
  expose :iam_instance_profile_id, expose_nil: false
  expose :source_dest_check
  expose :root_device_type
  expose :virtualization_type
  expose :tags, expose_nil: false
end