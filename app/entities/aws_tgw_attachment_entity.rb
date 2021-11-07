class AwsTgwAttachmentEntity < ResourceEntity
  expose :tgw_attch_id
  expose :tgw_id
  expose :tgw_owner_id
  expose :resource_owner_id
  expose :resource_type
  expose :resource_id
  expose :state
  expose :tags, expose_nil: false
end