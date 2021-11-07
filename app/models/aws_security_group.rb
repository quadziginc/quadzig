class AwsSecurityGroup < ApplicationRecord
  include Edgeable
  belongs_to :aws_vpc
  belongs_to :aws_resource, polymorphic: true, optional: true
  has_one :aws_account, through: :aws_vpc

  alias_attribute :last_updated_at, :last_synced_at
  delegate :vpc_id, to: :aws_vpc
end
