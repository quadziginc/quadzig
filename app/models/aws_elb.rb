class AwsElb < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_elb_security_groups, dependent: :destroy

  track_issues high: [
    proc { |obj| { az_count: 1 } if obj.availability_zones.size == 1 }
  ], medium: [
    proc { |obj| { deprecated: true } }
  ]

  def is_split_across_subnets
    false
  end
end
