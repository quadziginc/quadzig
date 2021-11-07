require 'parslet'

class SearchParser < Parslet::Parser
  rule(:spaces)  { match('\s').repeat(1) }
  rule(:spaces?) { spaces.maybe }
  rule(:comma)   { spaces? >> str(',') >> spaces? }

  rule(:value) {
    ((str(',').absent? >> any).repeat).as(:value)
  }

  # TODO: Best way to do this?
  # Remember to keep the number of fields less than 600!!!
  # ElasticSearch can't handle more than 1000 fields per index (read perf issues)

  # This list should always be sorted in REVERSE ALPHABETICAL ORDER
  rule(:valid_keys) {
    str('vpc_id')                                     |
    str('virtualization_type')                        |
    str('version')                                    |
    str('transit_encryption_enabled')                 |
    str('timezone')                                   |
    str('tgw_owner_id')                               |
    str('tgw_id')                                     |
    str('tgw_attch_id')                               |
    str('tgw_arn')                                    |
    str('task_definition')                            |
    str('tags.value')                                 |
    str('tags.key')                                   |
    str('subnet_id')                                  |
    str('subnet_group_status')                        |
    str('storage_type')                               |
    str('status')                                     |
    str('state')                                      |
    str('source_security_group_owner_alias')          |
    str('source_security_group_group_name')           |
    str('source_dest_check')                          |
    str('snapshot_retention_limit')                   |
    str('service_name')                               |
    str('service_linked_role_arn')                    |
    str('service_arn')                                |
    str('secondary_availability_zone')                |
    str('scheme')                                     |
    str('scheduling_strategy')                        |
    str('scaling_min_size')                           |
    str('scaling_max_size')                           |
    str('scaling_desired_size')                       |
    str('running_tasks_count')                        |
    str('running_count')                              |
    str('rt')                                         |
    str('root_device_type')                           |
    str('role_arn')                                   |
    str('resource_type')                              |
    str('resource_owner_id')                          |
    str('resource_id')                                |
    str('replication_group_log_delivery_enabled')     |
    str('replication_group_id')                       |
    str('replica_mode')                               |
    str('release_version')                            |
    str('registered_container_instances_count')       |
    str('region_code')                                |
    str('reader_endpoint')                            |
    str('read_replica_source_db_instance_identifier') |
    str('read_replica_identifiers')                   |
    str('read_replica_db_instance_identifiers')       |
    str('publicly_accessible')                        |
    str('public_ip_address')                          |
    str('public_dns_name')                            |
    str('propagate_tags')                             |
    str('private_ip_address')                         |
    str('private_dns_name')                           |
    str('preferred_availability_zone')                |
    str('platform_version')                           |
    str('platform')                                   |
    str('placement_group')                            |
    str('performance_insights_enabled')               |
    str('pending_tasks_count')                        |
    str('pending_count')                              |
    str('peering_id')                                 |
    str('owner_id')                                   |
    str('num_cache_nodes')                            |
    str('nodegroup_name')                             |
    str('nodegroup_arn')                              |
    str('node_role')                                  |
    str('ngw_id')                                     |
    str('new_instances_protected_from_scale_in')      |
    str('network_configuration')                      |
    str('name')                                       |
    str('multi_az')                                   |
    str('min_size')                                   |
    str('max_size')                                   |
    str('max_instance_lifetime')                      |
    str('max_allocated_storage')                      |
    str('load_balancer_name')                         |
    str('load_balancer_arn')                          |
    str('lb_type')                                    |
    str('launch_type')                                |
    str('launch_template_version')                    |
    str('launch_template_name')                       |
    str('launch_template_id')                         |
    str('launch_configuration_name')                  |
    str('key_name')                                   |
    str('is_default')                                 |
    str('ip_address_type')                            |
    str('iops')                                       |
    str('instance_type')                              |
    str('instance_id')                                |
    str('image_id')                                   |
    str('igw_id')                                     |
    str('iam_instance_profile_id')                    |
    str('iam_instance_profile_arn')                   |
    str('iam_database_authentication_enabled')        |
    str('health_check_unhealthy_threshold')           |
    str('health_check_type')                          |
    str('health_check_timeout')                       |
    str('health_check_target')                        |
    str('health_check_healthy_threshold')             |
    str('health_check_grace_period_seconds')          |
    str('health_check_grace_period')                  |
    str('events')                                     |
    str('engine_version')                             |
    str('engine')                                     |
    str('endpoint_address')                           |
    str('endpoint')                                   |
    str('enable_ecs_managed_tags')                    |
    str('elb')                                        |
    str('ec2_ssh_key')                                |
    str('ec2_asg')                                    |
    str('dns_name')                                   |
    str('disk_size')                                  |
    str('desired_count')                              |
    str('desired_capacity')                           |
    str('deletion_protection')                        |
    str('default_for_az')                             |
    str('default_cooldown')                           |
    str('db_subnet_group_name')                       |
    str('db_instance_identifier')                     |
    str('db_instance_class')                          |
    str('db_instance_arn')                            |
    str('db_cluster_resource_id')                     |
    str('db_cluster_identifier')                      |
    str('db_cluster_arn')                             |
    str('connectivity_type')                          |
    str('configuration_endpoint_port')                |
    str('configuration_endpoint_address')             |
    str('cluster_name')                               |
    str('cluster_arn')                                |
    str('cidr_block')                                 |
    str('capacity_type')                              |
    str('capacity_rebalance')                         |
    str('capacity')                                   |
    str('cache_subnet_group_name')                    |
    str('cache_node_type')                            |
    str('cache_cluster_status')                       |
    str('cache_cluster_id')                           |
    str('aws_rds_aurora_cluster_id')                  |
    str('aws_ecs_cluster_id')                         |
    str('aws_account_name')                           |
    str('aws_account_id')                             |
    str('available_ip_address_count')                 |
    str('availability_zones')                         |
    str('availability_zone')                          |
    str('auto_scaling_group_name')                    |
    str('auto_scaling_group_arn')                     |
    str('auto_minor_version_upgrade')                 |
    str('auto_acc_shrd_attch')                        |
    str('at_rest_encryption_enabled')                 |
    str('arn')                                        |
    str('architecture')                               |
    str('amz_side_asn')                               |
    str('ami_type')                                   |
    str('allocated_storage')                          |
    str('addresses')                                  |
    str('active_services_count')
  }

  rule(:key) {
    spaces? >> (
      str(':').absent? >> valid_keys
    ).repeat.as(:key) >> str(':')
  }

  rule(:query) {
    (
      key >> value
    ).as(:query) >> spaces?
  }

  rule(:queries) {
    spaces? >> (
      query >> (
        comma >> query
      ).repeat
    ).as(:queries) >> spaces?
  }

  root(:queries)
end

class ESTransform < Parslet::Transform
  rule(string: simple(:st)) { st.to_s }
  rule(query: subtree(:query)) do
    {
      term: {
        query[:key] => (query[:value]).to_s.strip
      }
    }
  end

  rule(queries: subtree(:query)) do |dict|
    if dict[:query].instance_of? Array
      final_query = dict[:query].map do |q|
        { match: q[:term] }
      end
      output = {query: {bool: { must: final_query } } }
    else
      # When there is only one key value pair
      # TODO: Fix this hack
      output = {query: {bool: { must: [{match: dict[:query][:term]}] } } }
    end
  end
end
