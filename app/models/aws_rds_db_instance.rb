class AwsRdsDbInstance < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_security_groups, as: :aws_resource, dependent: :destroy
  has_one :user, through: :aws_account

  track_issues high: [
    proc { |obj| { multi_az: 'disabled' } unless obj.multi_az },
    proc { |obj| { deletion_protection: 'disabled' } unless obj.deletion_protection },
    proc { |obj| { max_allocated_storage: 'disabled' } if obj.max_allocated_storage.nil? },
    proc { |obj| { storage_type: obj.storage_type } if obj.storage_type == 'standard' }
  ]

  def is_split_across_subnets
    false
  end
end
