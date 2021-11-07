class AwsElasticacheRgNodeGroup < ApplicationRecord
  belongs_to :aws_account
  belongs_to :aws_elasticache_replication_group
end