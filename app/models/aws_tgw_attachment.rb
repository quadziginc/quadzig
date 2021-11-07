class AwsTgwAttachment < ApplicationRecord
  belongs_to :aws_account
  belongs_to :aws_tgw, -> (obj) { obj.aws_account.aws_tgws }, foreign_key: :tgw_id, primary_key: :tgw_id

  def target_resource
    resource_type == "vpc" ? aws_account.aws_vpcs.find_by(vpc_id: resource_id) : nil
  end
end