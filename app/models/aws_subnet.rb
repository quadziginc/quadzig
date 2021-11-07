class AwsSubnet < ApplicationRecord
  belongs_to :aws_vpc
  belongs_to :aws_account
  has_many :aws_ec2_instances, dependent: :destroy
end