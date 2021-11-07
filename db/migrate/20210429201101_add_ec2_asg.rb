class AddEc2Asg < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_ec2_asgs, id: :uuid do |t|
      t.string :auto_scaling_group_name
      t.string :auto_scaling_group_arn
      t.string :launch_configuration_name
      t.string :launch_template_id
      t.string :launch_template_name
      t.string :launch_template_version
      t.integer :min_size
      t.integer :max_size
      t.integer :desired_capacity
      t.integer :default_cooldown
      t.string :availability_zones, array: true, default: []
      t.string :load_balancer_names, array: true, default: []
      t.string :target_group_arns, array: true, default: []
      t.string :health_check_type
      t.integer :health_check_grace_period
      t.datetime :created_time
      t.json :suspended_processes
      t.string :placement_group
      t.string :vpc_zone_identifier
      t.json :enabled_metrics
      t.string :status
      t.json :tags
      t.string :termination_policies, array: true, default: []
      t.boolean :new_instances_protected_from_scale_in
      t.string :service_linked_role_arn
      t.integer :max_instance_lifetime
      t.boolean :capacity_rebalance
      t.string :region_code
      t.datetime :last_updated_at
      t.string :vpc_id

      t.belongs_to :aws_account, type: :uuid
      t.timestamps
    end

    create_table :aws_ec2_asg_instances, id: :uuid do |t|
      t.string :instance_id
      t.string :instance_type
      t.string :availability_zone
      t.string :lifecycle_state
      t.string :health_status
      t.string :launch_configuration_name
      t.string :launch_template_id
      t.string :launch_template_name
      t.string :launch_template_version
      t.boolean :protected_from_scale_in
      t.integer :weighted_capacity
      t.string :auto_scaling_group_arn
      t.string :auto_scaling_group_name
      t.string :region_code
      t.datetime :last_updated_at
      t.string :vpc_id

      t.belongs_to :aws_ec2_asg, type: :uuid
      t.timestamps
    end
  end
end
