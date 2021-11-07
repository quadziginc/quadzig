# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_09_22_183759) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "aws_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "account_id"
    t.string "external_id", null: false
    t.string "active_regions", default: [], array: true
    t.string "ext_reference", null: false
    t.string "cf_stack_name", null: false
    t.boolean "role_associated", default: false
    t.string "iam_role_arn"
    t.boolean "creation_complete", default: false
    t.uuid "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "status"
    t.string "creation_errors", default: [], array: true
    t.uuid "cf_template_version_id"
    t.string "cf_stack_id"
    t.string "cf_region_code"
    t.json "view_config", default: {}
    t.index ["account_id"], name: "index_aws_accounts_on_account_id"
    t.index ["cf_template_version_id"], name: "index_aws_accounts_on_cf_template_version_id"
    t.index ["user_id"], name: "index_aws_accounts_on_user_id"
  end

  create_table "aws_ec2_asg_instances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "instance_id"
    t.string "instance_type"
    t.string "availability_zone"
    t.string "lifecycle_state"
    t.string "health_status"
    t.string "launch_configuration_name"
    t.string "launch_template_id"
    t.string "launch_template_name"
    t.string "launch_template_version"
    t.boolean "protected_from_scale_in"
    t.integer "weighted_capacity"
    t.string "auto_scaling_group_arn"
    t.string "auto_scaling_group_name"
    t.string "region_code"
    t.datetime "last_updated_at"
    t.string "vpc_id"
    t.uuid "aws_ec2_asg_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_ec2_asg_id"], name: "index_aws_ec2_asg_instances_on_aws_ec2_asg_id"
  end

  create_table "aws_ec2_asgs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "auto_scaling_group_name"
    t.string "auto_scaling_group_arn"
    t.string "launch_configuration_name"
    t.string "launch_template_id"
    t.string "launch_template_name"
    t.string "launch_template_version"
    t.integer "min_size"
    t.integer "max_size"
    t.integer "desired_capacity"
    t.integer "default_cooldown"
    t.string "availability_zones", default: [], array: true
    t.string "load_balancer_names", default: [], array: true
    t.string "target_group_arns", default: [], array: true
    t.string "health_check_type"
    t.integer "health_check_grace_period"
    t.datetime "created_time"
    t.json "suspended_processes"
    t.string "placement_group"
    t.string "vpc_zone_identifier"
    t.json "enabled_metrics"
    t.string "status"
    t.json "tags"
    t.string "termination_policies", default: [], array: true
    t.boolean "new_instances_protected_from_scale_in"
    t.string "service_linked_role_arn"
    t.integer "max_instance_lifetime"
    t.boolean "capacity_rebalance"
    t.string "region_code"
    t.datetime "last_updated_at"
    t.string "vpc_id"
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_ec2_asgs_on_aws_account_id"
  end

  create_table "aws_ec2_instances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "image_id"
    t.string "instance_id", null: false
    t.string "instance_type", null: false
    t.string "key_name"
    t.datetime "launch_time"
    t.string "platform"
    t.string "private_dns_name"
    t.string "private_ip_address"
    t.string "public_dns_name"
    t.string "public_ip_address"
    t.string "state"
    t.string "subnet_id", null: false
    t.string "vpc_id", null: false
    t.string "architecture"
    t.string "iam_instance_profile_arn"
    t.string "iam_instance_profile_id"
    t.string "region_code", null: false
    t.boolean "source_dest_check"
    t.json "security_groups"
    t.json "tags"
    t.uuid "aws_subnet_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "root_device_type"
    t.string "virtualization_type"
    t.datetime "last_updated_at"
    t.uuid "aws_account_id"
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_ec2_instances_on_aws_account_id"
    t.index ["aws_subnet_id"], name: "index_aws_ec2_instances_on_aws_subnet_id"
    t.index ["instance_id"], name: "index_aws_ec2_instances_on_instance_id"
    t.index ["subnet_id"], name: "index_aws_ec2_instances_on_subnet_id"
    t.index ["vpc_id"], name: "index_aws_ec2_instances_on_vpc_id"
  end

  create_table "aws_ec2_security_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "description"
    t.string "group_name"
    t.json "ip_permissions"
    t.string "owner_id"
    t.string "group_id"
    t.json "ip_permissions_egress"
    t.string "vpc_id"
    t.string "region_code"
    t.datetime "last_updated_at"
    t.uuid "aws_ec2_instance_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_ec2_instance_id"], name: "index_aws_ec2_security_groups_on_aws_ec2_instance_id"
  end

  create_table "aws_ecs_clusters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cluster_arn"
    t.string "cluster_name"
    t.string "status"
    t.integer "registered_container_instances_count"
    t.integer "running_tasks_count"
    t.integer "pending_tasks_count"
    t.integer "active_services_count"
    t.json "capacity_providers"
    t.json "default_capacity_provider_strategy"
    t.json "tags"
    t.string "region_code", null: false
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "last_updated_at"
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_ecs_clusters_on_aws_account_id"
    t.index ["cluster_arn"], name: "index_aws_ecs_clusters_on_cluster_arn"
  end

  create_table "aws_ecs_services", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "service_arn"
    t.string "service_name"
    t.string "cluster_arn"
    t.json "load_balancers"
    t.json "service_registries"
    t.string "status"
    t.integer "desired_count"
    t.integer "running_count"
    t.integer "pending_count"
    t.string "launch_type"
    t.json "capacity_provider_strategy"
    t.string "platform_version"
    t.string "task_definition"
    t.json "deployment_configuration"
    t.json "task_sets"
    t.json "deployments"
    t.string "role_arn"
    t.json "events"
    t.json "placement_constraints"
    t.json "placement_strategy"
    t.json "network_configuration"
    t.integer "health_check_grace_period_seconds"
    t.string "scheduling_strategy"
    t.json "deployment_controller"
    t.boolean "enable_ecs_managed_tags"
    t.string "propagate_tags"
    t.json "tags"
    t.string "region_code", null: false
    t.uuid "aws_account_id"
    t.uuid "aws_ecs_cluster_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "last_updated_at"
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_ecs_services_on_aws_account_id"
    t.index ["aws_ecs_cluster_id"], name: "index_aws_ecs_services_on_aws_ecs_cluster_id"
    t.index ["service_arn"], name: "index_aws_ecs_services_on_service_arn"
  end

  create_table "aws_eks_clusters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.string "arn"
    t.datetime "cluster_created_at"
    t.string "version"
    t.string "endpoint"
    t.string "role_arn"
    t.json "resources_vpc_config"
    t.json "kubernetes_network_config"
    t.json "logging"
    t.json "identity"
    t.string "status"
    t.json "certificate_authority"
    t.string "client_request_token"
    t.string "platform_version"
    t.json "tags"
    t.json "encryption_config"
    t.string "region_code", null: false
    t.datetime "last_updated_at"
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_eks_clusters_on_aws_account_id"
  end

  create_table "aws_eks_nodegroups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "nodegroup_name"
    t.string "nodegroup_arn"
    t.string "cluster_name"
    t.string "version"
    t.string "release_version"
    t.datetime "nodegroup_created_at"
    t.datetime "nodegroup_modified_at"
    t.string "status"
    t.string "capacity_type"
    t.integer "scaling_min_size"
    t.integer "scaling_max_size"
    t.integer "scaling_desired_size"
    t.string "instance_types", default: [], array: true
    t.string "subnets", default: [], array: true
    t.string "ec2_ssh_key"
    t.string "source_security_groups", default: [], array: true
    t.string "ami_type"
    t.string "node_role"
    t.json "labels"
    t.json "taints"
    t.json "resources"
    t.integer "disk_size"
    t.json "health"
    t.string "launch_template_name"
    t.string "launch_template_id"
    t.string "launch_template_version"
    t.json "tags"
    t.string "region_code", null: false
    t.datetime "last_updated_at"
    t.uuid "aws_account_id"
    t.uuid "aws_eks_cluster_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_eks_nodegroups_on_aws_account_id"
    t.index ["aws_eks_cluster_id"], name: "index_aws_eks_nodegroups_on_aws_eks_cluster_id"
  end

  create_table "aws_elasticache_cluster_nodes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cache_node_id"
    t.string "cache_node_status"
    t.datetime "cache_node_create_time"
    t.string "endpoint_address"
    t.integer "endpoint_port"
    t.string "parameter_group_status"
    t.string "source_cache_node_id"
    t.string "customer_availability_zone"
    t.string "customer_outpost_arn"
    t.datetime "last_updated_at"
    t.string "region_code", null: false
    t.uuid "aws_account_id"
    t.uuid "aws_elasticache_cluster_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_elasticache_cluster_nodes_on_aws_account_id"
    t.index ["aws_elasticache_cluster_id"], name: "idx_aws_ec_nodes_on_aws_ec_clstr"
  end

  create_table "aws_elasticache_clusters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cache_cluster_id"
    t.string "configuration_endpoint_address"
    t.integer "configuration_endpoint_port"
    t.string "client_download_landing_page"
    t.string "cache_node_type"
    t.string "engine"
    t.string "engine_version"
    t.string "cache_cluster_status"
    t.integer "num_cache_nodes"
    t.string "preferred_availability_zone"
    t.string "preferred_outpost_arn"
    t.datetime "cache_cluster_create_time"
    t.string "preferred_maintenance_window"
    t.json "pending_modified_values"
    t.json "notification_configuration"
    t.json "cache_security_groups"
    t.json "cache_parameter_group"
    t.string "cache_subnet_group_name"
    t.boolean "auto_minor_version_upgrade"
    t.json "security_groups"
    t.string "replication_group_id"
    t.integer "snapshot_retention_limit"
    t.string "snapshot_window"
    t.boolean "auth_token_enabled"
    t.datetime "auth_token_last_modified_date"
    t.boolean "transit_encryption_enabled"
    t.boolean "at_rest_encryption_enabled"
    t.string "arn"
    t.boolean "replication_group_log_delivery_enabled"
    t.json "log_delivery_configurations"
    t.json "tags"
    t.datetime "last_updated_at"
    t.string "region_code", null: false
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_elasticache_clusters_on_aws_account_id"
  end

  create_table "aws_elasticache_replication_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "replication_group_id"
    t.string "description"
    t.string "status"
    t.json "pending_modified_values"
    t.string "member_clusters", default: [], array: true
    t.string "snapshotting_cluster_id"
    t.string "automatic_failover"
    t.string "multi_az"
    t.string "configuration_endpoint_address"
    t.integer "configuration_endpoint_port"
    t.integer "snapshot_retention_limit"
    t.string "snapshot_window"
    t.boolean "cluster_enabled"
    t.string "cache_node_type"
    t.boolean "auth_token_enabled"
    t.string "auth_token_last_modified_date"
    t.boolean "transit_encryption_enabled"
    t.boolean "at_rest_encryption_enabled"
    t.string "member_clusters_outpost_arns", default: [], array: true
    t.string "kms_key_id"
    t.string "arn"
    t.string "user_group_ids", default: [], array: true
    t.json "log_delivery_configurations"
    t.json "tags"
    t.datetime "last_updated_at"
    t.string "region_code", null: false
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_elasticache_replication_groups_on_aws_account_id"
  end

  create_table "aws_elasticache_rg_node_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "node_group_id"
    t.string "status"
    t.string "primary_endpoint_address"
    t.integer "primary_endpoint_port"
    t.string "reader_endpoint_address"
    t.integer "reader_endpoint_port"
    t.string "slots"
    t.json "node_group_members"
    t.datetime "last_updated_at"
    t.string "region_code", null: false
    t.uuid "aws_account_id"
    t.uuid "aws_elasticache_replication_group_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_elasticache_rg_node_groups_on_aws_account_id"
    t.index ["aws_elasticache_replication_group_id"], name: "idx_aws_ec_rg_ngs_on_aws_ec_rg_id"
  end

  create_table "aws_elb_security_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "description"
    t.string "group_name"
    t.json "ip_permissions"
    t.string "owner_id"
    t.string "group_id"
    t.json "ip_permissions_egress"
    t.string "vpc_id"
    t.string "region_code"
    t.datetime "last_updated_at"
    t.uuid "aws_elb_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_elb_id"], name: "index_aws_elb_security_groups_on_aws_elb_id"
  end

  create_table "aws_elbs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "load_balancer_name", null: false
    t.string "dns_name"
    t.string "vpc_id"
    t.string "canonical_hosted_zone_name"
    t.string "canonical_hosted_zone_name_id"
    t.json "listener_descriptions"
    t.json "policies"
    t.json "backend_server_descriptions"
    t.string "health_check_target"
    t.integer "health_check_interval"
    t.integer "health_check_timeout"
    t.integer "health_check_unhealthy_threshold"
    t.integer "health_check_healthy_threshold"
    t.string "source_security_group_owner_alias"
    t.string "source_security_group_group_name"
    t.string "availability_zones", default: [], array: true
    t.string "security_groups", default: [], array: true
    t.string "subnets", default: [], array: true
    t.string "instances", default: [], array: true
    t.datetime "created_time"
    t.json "tags"
    t.string "region_code"
    t.string "scheme"
    t.datetime "last_updated_at"
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_elbs_on_aws_account_id"
  end

  create_table "aws_igws", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "igw_id", null: false
    t.string "owner_id", null: false
    t.string "vpc_id"
    t.string "region_code", null: false
    t.datetime "last_updated_at"
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_igws_on_aws_account_id"
    t.index ["igw_id"], name: "index_aws_igws_on_igw_id"
    t.index ["vpc_id"], name: "index_aws_igws_on_vpc_id"
  end

  create_table "aws_lb_security_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "description"
    t.string "group_name"
    t.json "ip_permissions"
    t.string "owner_id"
    t.string "group_id"
    t.json "ip_permissions_egress"
    t.string "vpc_id"
    t.string "region_code"
    t.datetime "last_updated_at"
    t.uuid "aws_load_balancer_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_load_balancer_id"], name: "index_aws_lb_security_groups_on_aws_load_balancer_id"
  end

  create_table "aws_load_balancers", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "load_balancer_arn"
    t.string "dns_name"
    t.datetime "created_time"
    t.string "load_balancer_name"
    t.string "scheme"
    t.string "vpc_id"
    t.string "state"
    t.string "lb_type"
    t.json "availability_zones"
    t.json "security_groups"
    t.string "region_code"
    t.json "tags"
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "ip_address_type"
    t.datetime "last_updated_at"
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_load_balancers_on_aws_account_id"
    t.index ["vpc_id"], name: "index_aws_load_balancers_on_vpc_id"
  end

  create_table "aws_ngws", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "ngw_id", null: false
    t.string "vpc_id", null: false
    t.json "addresses"
    t.string "subnet_id"
    t.string "region_code", null: false
    t.datetime "last_updated_at"
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_ngws_on_aws_account_id"
    t.index ["ngw_id"], name: "index_aws_ngws_on_ngw_id"
    t.index ["subnet_id"], name: "index_aws_ngws_on_subnet_id"
    t.index ["vpc_id"], name: "index_aws_ngws_on_vpc_id"
  end

  create_table "aws_peered_accepter_vpcs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "aws_peering_connection_id"
    t.string "cidr_block", null: false
    t.string "owner_id", null: false
    t.string "vpc_id", null: false
    t.string "region_code", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_peering_connection_id"], name: "index_aws_peered_accepter_vpcs_on_aws_peering_connection_id"
    t.index ["vpc_id"], name: "index_aws_peered_accepter_vpcs_on_vpc_id"
  end

  create_table "aws_peered_requester_vpcs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "aws_peering_connection_id"
    t.string "cidr_block", null: false
    t.string "owner_id", null: false
    t.string "vpc_id", null: false
    t.string "region_code", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_peering_connection_id"], name: "index_aws_peered_requester_vpcs_on_aws_peering_connection_id"
    t.index ["vpc_id"], name: "index_aws_peered_requester_vpcs_on_vpc_id"
  end

  create_table "aws_peering_connections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "aws_account_id"
    t.string "peering_id", null: false
    t.string "region_code", null: false
    t.datetime "last_updated_at"
    t.uuid "aws_peered_requester_vpc_id"
    t.uuid "aws_peered_accepter_vpc_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_peering_connections_on_aws_account_id"
    t.index ["aws_peered_accepter_vpc_id"], name: "index_aws_peering_connections_on_aws_peered_accepter_vpc_id"
    t.index ["aws_peered_requester_vpc_id"], name: "index_aws_peering_connections_on_aws_peered_requester_vpc_id"
    t.index ["peering_id"], name: "index_aws_peering_connections_on_peering_id"
  end

  create_table "aws_rds_aurora_clusters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "availability_zones", default: [], array: true
    t.string "db_cluster_identifier", null: false
    t.string "endpoint"
    t.string "reader_endpoint"
    t.boolean "multi_az"
    t.string "engine"
    t.string "engine_version"
    t.string "read_replica_identifiers", default: [], array: true
    t.string "vpc_security_groups", default: [], array: true
    t.string "db_cluster_resource_id"
    t.string "db_cluster_arn"
    t.string "capacity"
    t.json "tag_list"
    t.string "region_code", null: false
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "last_updated_at"
    t.boolean "deletion_protection"
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_rds_aurora_clusters_on_aws_account_id"
  end

  create_table "aws_rds_aurora_db_instances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "db_instance_identifier", null: false
    t.string "db_instance_class", null: false
    t.string "engine", null: false
    t.string "endpoint_address"
    t.integer "allocated_storage", null: false
    t.json "db_security_groups"
    t.json "vpc_security_groups"
    t.json "db_parameter_groups"
    t.string "db_subnet_group_name"
    t.string "subnet_group_status"
    t.json "subnets"
    t.string "availability_zone"
    t.string "secondary_availability_zone"
    t.boolean "multi_az"
    t.string "engine_version"
    t.boolean "auto_minor_version_upgrade"
    t.string "read_replica_source_db_instance_identifier"
    t.string "read_replica_db_instance_identifiers", default: [], array: true
    t.string "replica_mode"
    t.integer "iops"
    t.boolean "publicly_accessible"
    t.string "storage_type"
    t.string "db_cluster_identifier"
    t.string "db_instance_arn"
    t.string "timezone"
    t.boolean "iam_database_authentication_enabled"
    t.boolean "performance_insights_enabled"
    t.boolean "deletion_protection"
    t.json "tag_list"
    t.integer "max_allocated_storage"
    t.string "vpc_id"
    t.string "region_code", null: false
    t.uuid "aws_rds_aurora_cluster_id"
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "last_updated_at"
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_rds_aurora_db_instances_on_aws_account_id"
    t.index ["aws_rds_aurora_cluster_id"], name: "index_aws_rds_aurora_db_instances_on_aws_rds_aurora_cluster_id"
    t.index ["db_instance_arn"], name: "index_aws_rds_aurora_db_instances_on_db_instance_arn"
  end

  create_table "aws_rds_db_instances", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "db_instance_identifier", null: false
    t.string "db_instance_class", null: false
    t.string "engine", null: false
    t.string "endpoint_address"
    t.integer "allocated_storage", null: false
    t.json "db_security_groups"
    t.json "vpc_security_groups"
    t.json "db_parameter_groups"
    t.string "db_subnet_group_name"
    t.string "subnet_group_status"
    t.json "subnets"
    t.string "availability_zone"
    t.string "secondary_availability_zone"
    t.boolean "multi_az"
    t.string "engine_version"
    t.boolean "auto_minor_version_upgrade"
    t.string "read_replica_source_db_instance_identifier"
    t.string "read_replica_db_instance_identifiers", default: [], array: true
    t.string "replica_mode"
    t.integer "iops"
    t.boolean "publicly_accessible"
    t.string "storage_type"
    t.string "db_cluster_identifier"
    t.string "db_instance_arn"
    t.string "timezone"
    t.boolean "iam_database_authentication_enabled"
    t.boolean "performance_insights_enabled"
    t.boolean "deletion_protection"
    t.json "tag_list"
    t.integer "max_allocated_storage"
    t.string "vpc_id"
    t.string "region_code", null: false
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "last_updated_at"
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_rds_db_instances_on_aws_account_id"
    t.index ["db_instance_arn"], name: "index_aws_rds_db_instances_on_db_instance_arn"
  end

  create_table "aws_regions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "full_name", null: false
    t.string "region_code", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "availability_zones", default: [], array: true
  end

  create_table "aws_security_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "aws_vpc_id"
    t.string "aws_resource_type"
    t.uuid "aws_resource_id"
    t.string "region_code"
    t.string "description"
    t.string "group_name"
    t.json "ip_permissions"
    t.string "owner_id"
    t.string "group_id"
    t.json "ip_permissions_egress"
    t.json "tags"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.datetime "last_synced_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["aws_resource_type", "aws_resource_id"], name: "index_on_aws_resource_type_and_aws_resource_id"
    t.index ["aws_vpc_id"], name: "index_aws_security_groups_on_aws_vpc_id"
    t.index ["region_code"], name: "index_aws_security_groups_on_region_code"
  end

  create_table "aws_subnets", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "availability_zone", null: false
    t.integer "available_ip_address_count", default: 9999999
    t.string "cidr_block", null: false
    t.boolean "default_for_az", default: false
    t.string "subnet_id", null: false
    t.datetime "last_updated_at"
    t.string "region_code"
    t.uuid "aws_vpc_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "connectivity_type"
    t.uuid "aws_account_id"
    t.json "tags"
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_subnets_on_aws_account_id"
    t.index ["aws_vpc_id"], name: "index_aws_subnets_on_aws_vpc_id"
    t.index ["subnet_id"], name: "index_aws_subnets_on_subnet_id"
  end

  create_table "aws_tgw_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "aws_account_id"
    t.datetime "last_updated_at"
    t.string "tgw_attch_id"
    t.string "tgw_id"
    t.string "tgw_owner_id"
    t.string "region_code"
    t.string "resource_owner_id"
    t.string "resource_type"
    t.string "resource_id"
    t.string "state"
    t.json "tags"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_tgw_attachments_on_aws_account_id"
    t.index ["tgw_attch_id"], name: "index_aws_tgw_attachments_on_tgw_attch_id"
  end

  create_table "aws_tgws", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "tgw_id", null: false
    t.string "tgw_arn", null: false
    t.string "owner_id", null: false
    t.string "amz_side_asn", null: false
    t.boolean "auto_acc_shrd_attch"
    t.json "tags"
    t.string "region_code", null: false
    t.datetime "last_updated_at"
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_tgws_on_aws_account_id"
    t.index ["tgw_arn"], name: "index_aws_tgws_on_tgw_arn"
    t.index ["tgw_id"], name: "index_aws_tgws_on_tgw_id"
  end

  create_table "aws_vpcs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "vpc_id", null: false
    t.boolean "is_default"
    t.json "tags"
    t.string "region_code", null: false
    t.datetime "last_updated_at"
    t.string "cidr_block", null: false
    t.uuid "aws_account_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.json "view_config", default: {}
    t.index ["aws_account_id"], name: "index_aws_vpcs_on_aws_account_id"
    t.index ["vpc_id"], name: "index_aws_vpcs_on_vpc_id"
  end

  create_table "cf_template_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "cf_link", null: false
    t.string "version", null: false
    t.boolean "is_latest", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["cf_link"], name: "index_cf_template_versions_on_cf_link", unique: true
    t.index ["version"], name: "index_cf_template_versions_on_version", unique: true
  end

  create_table "cognito_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.integer "expire_time", null: false
    t.integer "issued_time", null: false
    t.string "audience", null: false
    t.text "refresh_token", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_cognito_sessions_on_user_id"
  end

  create_table "mfa_devices", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "device_name", null: false
    t.uuid "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_mfa_devices_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.text "message"
    t.string "type", default: "web"
    t.datetime "valid_from", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "valid_till", default: -> { "(CURRENT_TIMESTAMP + '1 day'::interval)" }, null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "resource_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name"
    t.json "accounts", default: {}
    t.json "display_config", default: {}
    t.boolean "default", default: false
    t.uuid "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_resource_groups_on_user_id"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "tier", default: "free", null: false
    t.string "stripe_id"
    t.string "stripe_subscription_item_id"
    t.string "stripe_subscription_id"
    t.integer "aws_account_quantity"
    t.uuid "user_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "last_card_digits"
    t.string "card_expiry_year"
    t.string "card_expiry_month"
    t.string "card_brand"
    t.string "payment_id"
    t.index ["stripe_id"], name: "index_subscriptions_on_stripe_id"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "subscriber", null: false
    t.string "email", null: false
    t.boolean "refresh_ongoing", default: false
    t.string "ignored_aws_vpcs", default: [], array: true
    t.string "ignored_aws_subnets", default: [], array: true
    t.boolean "ignore_default_vpcs", default: false
    t.bigint "subscription_id"
    t.float "current_bill"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.datetime "refresh_started_at"
    t.string "usersnap_id"
    t.index ["email"], name: "index_users_on_email"
    t.index ["subscriber"], name: "index_users_on_subscriber", unique: true
    t.index ["subscription_id"], name: "index_users_on_subscription_id"
  end

  add_foreign_key "aws_accounts", "users"
  add_foreign_key "aws_ec2_instances", "aws_accounts"
  add_foreign_key "aws_subnets", "aws_accounts"
end
