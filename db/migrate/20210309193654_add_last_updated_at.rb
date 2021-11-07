class AddLastUpdatedAt < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_ec2_instances, :last_updated_at, :datetime
    add_column :aws_ecs_clusters, :last_updated_at, :datetime
    add_column :aws_ecs_services, :last_updated_at, :datetime
    add_column :aws_load_balancers, :last_updated_at, :datetime
    add_column :aws_rds_aurora_clusters, :last_updated_at, :datetime
    add_column :aws_rds_aurora_db_instances, :last_updated_at, :datetime
    add_column :aws_rds_db_instances, :last_updated_at, :datetime
  end
end
