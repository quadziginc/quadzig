class AwsEc2SecurityGroup < ApplicationRecord
  include Edgeable
  belongs_to :aws_ec2_instance
  has_one :aws_account, through: :aws_ec2_instance

  alias aws_resource aws_ec2_instance
end