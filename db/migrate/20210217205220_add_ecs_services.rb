class AddEcsServices < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_ecs_services, id: :uuid do |t|
      t.string :service_arn, index: true
      t.string :service_name
      t.string :cluster_arn
      t.json :load_balancers
      t.json :service_registries
      t.string :status
      t.integer :desired_count
      t.integer :running_count
      t.integer :pending_count
      t.string :launch_type
      t.json :capacity_provider_strategy
      t.string :platform_version
      t.string :task_definition
      t.json :deployment_configuration
      t.json :task_sets
      t.json :deployments
      t.string :role_arn
      # TODO: This will probably fill up the db. Move this out eventually.
      t.json :events
      t.json :placement_constraints
      t.json :placement_strategy
      t.json :network_configuration
      t.integer :health_check_grace_period_seconds
      t.string :scheduling_strategy
      t.json :deployment_controller
      t.boolean :enable_ecs_managed_tags
      t.string :propagate_tags
      t.json :tags

      t.string :region_code, null: false
      t.belongs_to :aws_account, type: :uuid
      t.belongs_to :aws_ecs_cluster, type: :uuid
      t.timestamps
    end
  end
end
