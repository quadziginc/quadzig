class AwsEc2AsgInstance < ApplicationRecord
  belongs_to :aws_ec2_asg
  has_one :aws_account, through: :aws_ec2_asg
  has_one :aws_ec2_instance, lambda { |obj|
                               where(aws_account_id: obj.aws_ec2_asg.aws_account)
                             }, primary_key: :instance_id, foreign_key: :instance_id
  has_many :aws_ec2_security_groups, through: :aws_ec2_instance
end
