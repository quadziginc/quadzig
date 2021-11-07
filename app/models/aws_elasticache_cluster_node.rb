class AwsElasticacheClusterNode < ApplicationRecord
  belongs_to :aws_account
  belongs_to :aws_elasticache_cluster
end