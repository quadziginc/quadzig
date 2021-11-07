class AwsElasticacheReplicationGroup < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_elasticache_rg_node_groups, dependent: :destroy

  track_issues high: [
    proc { |obj| { status: obj.status } unless %w(creating available).include? obj.status },
    proc { |obj| { automatic_failover: obj.automatic_failover } unless obj.automatic_failover == 'enabled' },
    proc { |obj| { multi_az: obj.multi_az} unless obj.multi_az == 'enabled' },
    proc { |obj| { backups: false} if obj.snapshot_retention_limit == 0 }
  ]
end