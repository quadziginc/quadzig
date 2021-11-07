class AddElb < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_elbs, id: :uuid do |t|
      t.string :load_balancer_name, null: false
      t.string :dns_name
      t.string :vpc_id
      t.string :canonical_hosted_zone_name
      t.string :canonical_hosted_zone_name_id
      t.json :listener_descriptions
      t.json :policies
      t.json :backend_server_descriptions
      t.string :health_check_target
      t.integer :health_check_interval
      t.integer :health_check_timeout
      t.integer :health_check_unhealthy_threshold
      t.integer :health_check_healthy_threshold
      t.string :source_security_group_owner_alias
      t.string :source_security_group_group_name
      t.string :availability_zones, array: true, default: []
      t.string :security_groups, array: true, default: []
      t.string :subnets, array: true, default: []
      t.string :instances, array: true, default: []
      t.datetime :created_time
      t.json :tags
      t.string :region_code
      t.string :scheme

      t.datetime :last_updated_at
      t.belongs_to :aws_account, type: :uuid
      t.timestamps
    end
  end
end
