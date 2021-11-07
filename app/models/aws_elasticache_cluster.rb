class AwsElasticacheCluster < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_elasticache_cluster_nodes, dependent: :destroy

  track_issues high: [
    proc { |obj| { version: obj.engine_version } if [
      "5.0.0","5.0.3","5.0.4","5.0.5","2.6.13","2.8.6","2.8.19",
      "1.6.6","1.5.16","1.5.10","1.4.34","1.4.33","1.4.24","1.4.14","1.4.5"
    ].include? obj.engine_version },
    proc { |obj| { backups: false} if obj.snapshot_retention_limit == 0 },
    proc { |obj| { status: obj.status } unless %w(creating available).include? obj.cache_cluster_status },
  ]
end