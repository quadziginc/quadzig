class AddEks < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_eks_clusters, id: :uuid do |t|
      t.string :name
      t.string :arn
      t.datetime :cluster_created_at
      t.string :version
      t.string :endpoint
      t.string :role_arn
      t.json :resources_vpc_config
      t.json :kubernetes_network_config
      t.json :logging
      t.json :identity
      t.string :status
      t.json :certificate_authority
      t.string :client_request_token
      t.string :platform_version
      t.json :tags
      t.json :encryption_config

      t.string :region_code, null: false
      t.datetime :last_updated_at
      t.belongs_to :aws_account, type: :uuid
      t.timestamps
    end

    create_table :aws_eks_nodegroups, id: :uuid do |t|
      t.string :nodegroup_name
      t.string :nodegroup_arn
      t.string :cluster_name
      t.string :version
      t.string :release_version
      t.datetime :nodegroup_created_at
      t.datetime :nodegroup_modified_at
      t.string :status
      t.string :capacity_type
      t.integer :scaling_min_size
      t.integer :scaling_max_size
      t.integer :scaling_desired_size
      t.string :instance_types, array: true, default: []
      t.string :subnets, array: true, default: []
      t.string :ec2_ssh_key
      t.string :source_security_groups, array: true, default: []
      t.string :ami_type
      t.string :node_role
      t.json :labels
      t.json :taints
      t.json :resources
      t.integer :disk_size
      t.json :health
      t.string :launch_template_name
      t.string :launch_template_id
      t.string :launch_template_version
      t.json :tags

      t.string :region_code, null: false
      t.datetime :last_updated_at
      t.belongs_to :aws_account, type: :uuid
      t.belongs_to :aws_eks_cluster, type: :uuid
      t.timestamps
    end
  end
end
