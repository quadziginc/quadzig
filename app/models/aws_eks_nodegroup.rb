class AwsEksNodegroup < ApplicationRecord
  belongs_to :aws_account
  belongs_to :aws_eks_cluster

  track_issues high: [
    proc { |obj| { status: obj.status } unless %w[CREATING ACTIVE UPDATING].include? obj.status },
    proc { |obj|
      issues = obj.health.to_h.fetch("issues", [])
      issues.empty? ? nil : { issues: issues }
    }
  ]

  def aws_subnets
    aws_account.aws_subnets.where(subnet_id: subnets)
  end

  def is_split_across_subnets
    true
  end
end