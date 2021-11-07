class AwsElbSecurityGroup < ApplicationRecord
  include Edgeable
  belongs_to :aws_elb
  has_one :aws_account, through: :aws_elb

  alias aws_resource aws_elb
end