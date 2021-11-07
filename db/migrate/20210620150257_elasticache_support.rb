class ElasticacheSupport < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_elasticache_clusters, id: :uuid do |t|
      t.string :cache_cluster_id
      t.string :configuration_endpoint_address
      t.integer :configuration_endpoint_port
      t.string :client_download_landing_page
      t.string :cache_node_type
      t.string :engine
      t.string :engine_version
      t.string :cache_cluster_status
      t.integer :num_cache_nodes
      t.string :preferred_availability_zone
      t.string :preferred_outpost_arn
      t.datetime :cache_cluster_create_time
      t.string :preferred_maintenance_window
      t.json :pending_modified_values
      t.json :notification_configuration
      t.json :cache_security_groups
      t.json :cache_parameter_group
      t.string :cache_subnet_group_name
      t.boolean :auto_minor_version_upgrade
      t.json :security_groups
      t.string :replication_group_id
      t.integer :snapshot_retention_limit
      t.string :snapshot_window
      t.boolean :auth_token_enabled
      t.datetime :auth_token_last_modified_date
      t.boolean :transit_encryption_enabled
      t.boolean :at_rest_encryption_enabled
      t.string :arn
      t.boolean :replication_group_log_delivery_enabled
      t.json :log_delivery_configurations
      t.json :tags

      t.datetime :last_updated_at
      t.string :region_code, null: false
      t.belongs_to :aws_account, type: :uuid
      t.timestamps
    end

    create_table :aws_elasticache_cluster_nodes, id: :uuid do |t|
      t.string :cache_node_id
      t.string :cache_node_status
      t.datetime :cache_node_create_time
      t.string :endpoint_address
      t.integer :endpoint_port
      t.string :parameter_group_status
      t.string :source_cache_node_id
      t.string :customer_availability_zone
      t.string :customer_outpost_arn

      t.datetime :last_updated_at
      t.string :region_code, null: false
      t.belongs_to :aws_account, type: :uuid
      t.belongs_to :aws_elasticache_cluster, type: :uuid, index: { name: "idx_aws_ec_nodes_on_aws_ec_clstr" }
      t.timestamps
    end

    create_table :aws_elasticache_replication_groups, id: :uuid do |t|
      t.string :replication_group_id
      t.string :description
      t.string :status
      t.json :pending_modified_values
      t.string :member_clusters, array: true, default: []
      t.string :snapshotting_cluster_id
      t.string :automatic_failover
      t.string :multi_az
      t.string :configuration_endpoint_address
      t.integer :configuration_endpoint_port
      t.integer :snapshot_retention_limit
      t.string :snapshot_window
      t.boolean :cluster_enabled
      t.string :cache_node_type
      t.boolean :auth_token_enabled
      t.string :auth_token_last_modified_date
      t.boolean :transit_encryption_enabled
      t.boolean :at_rest_encryption_enabled
      t.string :member_clusters_outpost_arns, array: true, default: []
      t.string :kms_key_id
      t.string :arn
      t.string :user_group_ids, array: true, default: []
      t.json :log_delivery_configurations
      t.json :tags

      t.datetime :last_updated_at
      t.string :region_code, null: false
      t.belongs_to :aws_account, type: :uuid
      t.timestamps
    end

    create_table :aws_elasticache_rg_node_groups, id: :uuid do |t|
      t.string :node_group_id
      t.string :status
      t.string :primary_endpoint_address
      t.integer :primary_endpoint_port
      t.string :reader_endpoint_address
      t.integer :reader_endpoint_port
      t.string :slots
      t.json :node_group_members

      t.datetime :last_updated_at
      t.string :region_code, null: false
      t.belongs_to :aws_account, type: :uuid
      t.belongs_to :aws_elasticache_replication_group, type: :uuid, index: { name: 'idx_aws_ec_rg_ngs_on_aws_ec_rg_id' }
      t.timestamps
    end
  end
end
