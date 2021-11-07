class AwsRdsAuroraCluster < ApplicationRecord
  belongs_to :aws_account
  has_many :aws_rds_aurora_db_instances, dependent: :destroy
end