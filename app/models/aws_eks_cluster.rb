class AwsEksCluster < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_eks_nodegroups, dependent: :destroy

  track_issues high: [
    proc { |obj| { version: obj.version } if ["1.16", "1.17"].include? obj.version }
  ], medium: [
    proc { |obj| { status: obj.status } unless %w(CREATING ACTIVE UPDATING).include? obj.status }
  ]
end