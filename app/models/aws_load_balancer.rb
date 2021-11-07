class AwsLoadBalancer < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_lb_security_groups, dependent: :destroy

  track_issues high: [
    proc { |obj| { state: obj.state } if %w[active_impaired failed].include?(obj.state) }
  ],
  medium: [
    proc { |obj| { ip_address_type: obj.ip_address_type } if obj.ip_address_type == 'ipv4' }
  ]

  def is_split_across_subnets
    false
  end
end