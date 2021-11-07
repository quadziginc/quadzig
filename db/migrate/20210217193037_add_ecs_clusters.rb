class AddEcsClusters < ActiveRecord::Migration[6.0]
  def change
    create_table :aws_ecs_clusters, id: :uuid do |t|
      t.string :cluster_arn, index: true
      t.string :cluster_name
      t.string :status
      t.integer :registered_container_instances_count
      t.integer :running_tasks_count
      t.integer :pending_tasks_count
      t.integer :active_services_count
      t.json :capacity_providers
      t.json :default_capacity_provider_strategy
      t.json :tags

      t.string :region_code, null: false
      t.belongs_to :aws_account, type: :uuid
      t.timestamps
    end
  end
end
