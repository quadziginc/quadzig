class AwsRdsAuroraDbInstance < ApplicationRecord
  belongs_to :aws_account
  belongs_to :aws_rds_aurora_cluster
  has_many :aws_security_groups, as: :aws_resource, dependent: :destroy

  track_issues high: [
    proc { |obj| { multi_az: 'disabled' } unless obj.multi_az },
    proc { |obj| { deletion_protection: 'disabled' } unless obj.deletion_protection }
  ], medium: [
    proc { |obj| { storage_type: 'standard' } if obj.storage_type == 'standard' }
  ]

  def is_split_across_subnets
    false
  end
end
