class AwsEc2Asg < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_ec2_asg_instances, dependent: :destroy
  has_many :aws_ec2_security_groups, through: :aws_ec2_asg_instances

  track_issues high: [
    proc { |obj| { multi_az: 'disabled' } if obj.availability_zones.count < 2 },
    proc { |obj| { metrics_enabled: 'disabled' } if obj.enabled_metrics.empty? }
  ], medium: [
    proc { |obj| { capacity_rebalance: 'disabled' } unless obj.capacity_rebalance },
    proc { |obj| { suspended_processes: obj.suspended_processes } unless obj.suspended_processes.empty? }
  ]

  def aws_ec2_security_groups
    aws_ec2_asg_instances.first&.aws_ec2_security_groups || []
  end

  def eks_node_group
    AwsEksNodegroup.where('resources::text LIKE ?', "%#{auto_scaling_group_name}%").first
  end

  def aws_subnets
    aws_account.aws_subnets.where(subnet_id: vpc_zone_identifier.split(","))
  end

  def is_split_across_subnets
    true
  end
end
