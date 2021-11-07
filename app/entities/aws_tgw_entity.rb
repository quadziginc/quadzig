class AwsTgwEntity < ResourceEntity
  expose :tgw_id
  expose :tgw_arn
  expose :owner_id
  expose :amz_side_asn
  expose :auto_acc_shrd_attch
  expose :tags, expose_nil: false
end