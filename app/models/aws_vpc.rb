class AwsVpc < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_subnets, dependent: :destroy
  has_many :aws_security_groups, dependent: :destroy

  def default_label
    label = tags ? tags.find(-> {{}}) { |t| t["key"] == "Name" }.fetch("value", vpc_id) : vpc_id
    label + " (#{cidr_block})"
  end
end
