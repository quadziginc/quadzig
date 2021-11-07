class AddDisplayConfigToResources < ActiveRecord::Migration[6.0]
  def change
    add_column :aws_ec2_asg_instances, :view_config, :json, default: {}
    add_column :aws_ec2_asgs, :view_config, :json, default: {}
    add_column :aws_ec2_instances, :view_config, :json, default: {}
    add_column :aws_ec2_security_groups, :view_config, :json, default: {}
    add_column :aws_ecs_clusters, :view_config, :json, default: {}
    add_column :aws_ecs_services, :view_config, :json, default: {}
    add_column :aws_eks_clusters, :view_config, :json, default: {}
    add_column :aws_eks_nodegroups, :view_config, :json, default: {}
    add_column :aws_elasticache_cluster_nodes, :view_config, :json, default: {}
    add_column :aws_elasticache_clusters, :view_config, :json, default: {}
    add_column :aws_elasticache_replication_groups, :view_config, :json, default: {}
    add_column :aws_elasticache_rg_node_groups, :view_config, :json, default: {}
    add_column :aws_elb_security_groups, :view_config, :json, default: {}
    add_column :aws_elbs, :view_config, :json, default: {}
    add_column :aws_igws, :view_config, :json, default: {}
    add_column :aws_lb_security_groups, :view_config, :json, default: {}
    add_column :aws_load_balancers, :view_config, :json, default: {}
    add_column :aws_ngws, :view_config, :json, default: {}
    add_column :aws_peered_accepter_vpcs, :view_config, :json, default: {}
    add_column :aws_peered_requester_vpcs, :view_config, :json, default: {}
    add_column :aws_peering_connections, :view_config, :json, default: {}
    add_column :aws_rds_aurora_clusters, :view_config, :json, default: {}
    add_column :aws_rds_aurora_db_instances, :view_config, :json, default: {}
    add_column :aws_rds_db_instances, :view_config, :json, default: {}
    add_column :aws_subnets, :view_config, :json, default: {}
    add_column :aws_tgw_attachments, :view_config, :json, default: {}
    add_column :aws_tgws, :view_config, :json, default: {}
    add_column :aws_vpcs, :view_config, :json, default: {}
  end
end
