class AwsLbSecurityGroup < ApplicationRecord
  include Edgeable
  belongs_to :aws_load_balancer
  has_one :aws_account, through: :aws_load_balancer

  alias aws_resource aws_load_balancer
end