class AddRdsAuroraCluster < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_rds_aurora_clusters, id: :uuid do |t|
      t.string :availability_zones, array: true, default: []
      t.string :db_cluster_identifier, null: false
      t.string :endpoint
      t.string :reader_endpoint
      t.boolean :multi_az
      t.string :engine
      t.string :engine_version
      t.string :read_replica_identifiers, array: true, default: []
      t.string :vpc_security_groups, array: true, default: []
      t.string :db_cluster_resource_id
      t.string :db_cluster_arn
      t.string :capacity
      t.string :deletion_protection
      t.json :tag_list

      t.string :region_code, null: false
      t.belongs_to :aws_account, type: :uuid
      t.timestamps
    end
  end
end
