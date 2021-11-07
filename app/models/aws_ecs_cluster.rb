class AwsEcsCluster < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_ecs_services

  track_issues high: [
    proc { |obj| { status: obj.status } if %w[FAILED DEPROVISIONING INACTIVE].include? obj.status }
  ]
end