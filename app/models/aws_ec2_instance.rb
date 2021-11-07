class AwsEc2Instance < ApplicationRecord
  belongs_to :aws_subnet
  belongs_to :aws_account
  has_many :aws_ec2_security_groups, dependent: :destroy
  has_one :aws_ec2_asg_instance, inverse_of: :aws_ec2_instance, primary_key: :instance_id, foreign_key: :instance_id
  has_one :aws_ec2_asg, through: :aws_ec2_asg_instance
  has_one :user, through: :aws_account
  has_one :aws_eks_nodegroup

  track_issues high: [
    proc { |obj| { virtualization_type: obj.virtualization_type } unless obj.virtualization_type == 'hvm' }
  ], medium: [
    proc { |obj| { root_device_type: obj.root_device_type } if obj.root_device_type == 'instance-store' }
  ]

  def is_split_across_subnets
    false
  end
end
