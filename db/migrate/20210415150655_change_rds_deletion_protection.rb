class ChangeRdsDeletionProtection < ActiveRecord::Migration[6.0]
  def change
    remove_column :aws_rds_aurora_clusters, :deletion_protection, :string
    add_column :aws_rds_aurora_clusters, :deletion_protection, :boolean
  end
end
