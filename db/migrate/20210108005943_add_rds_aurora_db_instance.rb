class AddRdsAuroraDbInstance < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_rds_aurora_db_instances, id: :uuid do |t|
      t.string :db_instance_identifier, null: false
      t.string :db_instance_class, null: false
      t.string :engine, null: false
      t.string :endpoint_address
      t.integer :allocated_storage, null: false
      t.json :db_security_groups
      t.json :vpc_security_groups
      t.json :db_parameter_groups
      t.string :db_subnet_group_name
      t.string :subnet_group_status
      t.json :subnets
      t.string :availability_zone
      t.string :secondary_availability_zone
      t.boolean :multi_az
      t.string :engine_version
      t.boolean :auto_minor_version_upgrade
      t.string :read_replica_source_db_instance_identifier
      t.string :read_replica_db_instance_identifiers, array: true, default: []
      t.string :replica_mode
      t.integer :iops
      t.boolean :publicly_accessible
      t.string :storage_type
      t.string :db_cluster_identifier
      t.string :db_instance_arn, index: true
      t.string :timezone
      t.boolean :iam_database_authentication_enabled
      t.boolean :performance_insights_enabled
      t.boolean :deletion_protection
      t.json :tag_list
      t.integer :max_allocated_storage
      t.string :vpc_id

      t.string :region_code, null: false
      t.belongs_to :aws_rds_aurora_cluster, type: :uuid
      t.belongs_to :aws_account, type: :uuid
      t.timestamps
    end
  end
end
