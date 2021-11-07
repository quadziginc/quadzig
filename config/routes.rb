require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  get '/sign_in', as: 'signin', to: 'sessions#signin'
  get '/sign_out', as: 'signout', to: 'sessions#signout'
  get '/sign_up', as: 'signup', to: 'sessions#signup'

  get 'auth/sign_in', to: 'auth#signin'
  get 'auth/sign_out', to: 'auth#signout'

  get '/accounts', as: 'aws_accounts', to: 'accounts#index'
  get '/accounts/new', as: 'add_aws_account', to: 'accounts#new'
  post '/accounts', as: 'create_aws_account', to: 'accounts#create'
  get '/accounts/:id', as: 'show_aws_account', to: 'accounts#show'
  put '/accounts/:id', as: 'update_aws_account', to: 'accounts#update'
  delete '/accounts/:id', as: 'delete_aws_account', to: 'accounts#delete'
  get '/accounts/cf_update/:id', as: 'update_account_cf', to: 'accounts#update_cf'
  get '/account_creation_status', as: 'account_creation_status', to: 'accounts#account_creation_status'
  post '/gen_ext_id', as: 'generate_external_id', to: 'accounts#gen_new_external_id'
  get '/01c62a2dc9925b820a120f077fdbb7e6319184b0', as: 'error', to: 'home#error'

  # get "/landing", to: redirect(ENV['WEBSITE_URL']), status: 302
  # get "/docs", to: redirect(ENV['DOCS_URL']), status: 302

  patch '/settings/ignore_lists', as: 'update_ignore_lists', to: 'settings#update_ignore_lists'
  get '/preferences', as: 'preferences', to: 'settings#preferences'
  get '/notifications', as: 'notifications', to: 'settings#notifications'
  post '/preferences/generate_mfa_qr_code', as: 'generate_mfa_qr_code', to: 'settings#generate_mfa_qr_code'
  post '/preferences/configure_mfa', as: 'configure_mfa', to: 'settings#configure_mfa'
  delete '/preferences/mfa_device', as: 'delete_mfa_device', to: 'settings#delete_mfa_device'

  get '/views/network', as: 'network_view', to: 'network_view#index'
  get '/views/network/aws_nodes', as: 'network_view_nodes', to: 'network_view#aws_nodes'
  get '/views/network/aws_edges', as: 'network_view_edges', to: 'network_view#aws_edges'
  get '/views/network/vpc_info', as: 'network_vpc_info', to: 'network_view#vpc_info'
  get '/views/network/subnet_info', as: 'network_subnet_info', to: 'network_view#subnet_info'
  get '/views/network/tgw_info', as: 'networktgw_info', to: 'network_view#tgw_info'
  get '/views/network/igw_info', as: 'network_igw_info', to: 'network_view#igw_info'
  get '/views/network/account_info', as: 'network_account_info', to: 'network_view#account_info'
  get '/views/network/region_info', as: 'network_region_info', to: 'network_view#region_info'
  get '/views/network/ngw_info', as: 'network_ngw_info', to: 'network_view#ngw_info'
  get '/views/network/peering_info', as: 'network_peering_info', to: 'network_view#peering_info'
  get '/views/network/tgwattch_info', as: 'network_tgw_attch_info', to: 'network_view#tgwattch_info'
  post '/views/network/refresh_infra', as: 'refresh_network_infra', to: 'network_view#refresh_infra'
  post '/views/network/export_csv', as: 'export_network_csv', to: 'network_view#export_csv'
  get '/views/network/ec2instance_info', as: 'network_ec2_instance_info', to: 'network_view#ec2instance_info'
  get '/views/network/rdsAuroraInstance_info', as: 'network_rds_aurora_instance_info', to: 'network_view#rdsAuroraInstance_info'
  get '/views/network/rdsPostgresInstance_info', as: 'network_rds_postgres_instance_info', to: 'network_view#rdsPostgresInstance_info'
  get '/views/network/rdsMysqlInstance_info', as: 'network_rds_mysql_instance_info', to: 'network_view#rdsMysqlInstance_info'
  get '/views/network/awsLb_info', as: 'network_load_balancer_info', to: 'network_view#lb_info'
  get '/views/network/ecsCluster_info', as: 'network_ecs_cluster_info', to: 'network_view#ecsCluster_info'
  get '/views/network/ecsService_info', as: 'network_ecs_service_info', to: 'network_view#ecsService_info'
  get '/views/network/ec2Asg_info', as: 'network_ec2_asg_info', to: 'network_view#ec2_asg_info'
  get '/views/network/awsElb_info', as: 'network_elb_info', to: 'network_view#elb_info'
  get '/views/network/eksCluster_info', as: 'network_eks_cluster_info', to: 'network_view#eksCluster_info'
  get '/views/network/eksNodegroup_info', as: 'network_eks_nodegroup_info', to: 'network_view#eksNodegroup_info'
  get '/views/network/elasticacheRg_info', as: 'network_ec_repl_group_info', to: 'network_view#elasticacheRg_info'
  get '/views/network/elasticacheRedisCluster_info', as: 'network_ec_redis_cluster_info', to: 'network_view#elasticacheCluster_info'
  get '/views/network/elasticacheMemcachedCluster_info', as: 'network_ec_memcached_cluster_info', to: 'network_view#elasticacheCluster_info'

  get '/views/infrastructure', as: 'infrastructure_view', to: 'infrastructure_view#index'
  get '/views/infrastructure/aws_nodes', as: 'infrastructure_view_nodes', to: 'infrastructure_view#aws_nodes'
  get '/views/infrastructure/aws_edges', as: 'infrastructure_view_edges', to: 'infrastructure_view#aws_edges'
  get '/views/infrastructure/vpc_info', as: 'infrastructure_vpc_info', to: 'infrastructure_view#vpc_info'
  get '/views/infrastructure/subnet_info', as: 'infrastructure_subnet_info', to: 'infrastructure_view#subnet_info'
  get '/views/infrastructure/tgw_info', as: 'infrastructure_tgw_info', to: 'infrastructure_view#tgw_info'
  get '/views/infrastructure/igw_info', as: 'infrastructure_igw_info', to: 'infrastructure_view#igw_info'
  get '/views/infrastructure/account_info', as: 'infrastructure_account_info', to: 'infrastructure_view#account_info'
  get '/views/infrastructure/region_info', as: 'infrastructure_region_info', to: 'infrastructure_view#region_info'
  get '/views/infrastructure/ngw_info', as: 'infrastructure_ngw_info', to: 'infrastructure_view#ngw_info'
  get '/views/infrastructure/peering_info', as: 'infrastructure_peering_info', to: 'infrastructure_view#peering_info'
  get '/views/infrastructure/tgwattch_info', as: 'infrastructure_tgw_attch_info', to: 'infrastructure_view#tgwattch_info'
  get '/views/infrastructure/ec2instance_info', as: 'infrastructure_ec2_instance_info', to: 'infrastructure_view#ec2instance_info'
  get '/views/infrastructure/rdsAuroraInstance_info', as: 'infrastructure_rds_aurora_instance_info', to: 'infrastructure_view#rdsAuroraInstance_info'
  get '/views/infrastructure/rdsPostgresInstance_info', as: 'infrastructure_rds_postgres_instance_info', to: 'infrastructure_view#rdsPostgresInstance_info'
  get '/views/infrastructure/rdsMysqlInstance_info', as: 'infrastructure_rds_mysql_instance_info', to: 'infrastructure_view#rdsMysqlInstance_info'
  get '/views/infrastructure/awsLb_info', as: 'infrastructure_load_balancer_info', to: 'infrastructure_view#lb_info'
  get '/views/infrastructure/ecsCluster_info', as: 'infrastructure_ecs_cluster_info', to: 'infrastructure_view#ecsCluster_info'
  get '/views/infrastructure/ecsService_info', as: 'infrastructure_ecs_service_info', to: 'infrastructure_view#ecsService_info'
  get '/views/infrastructure/ec2Asg_info', as: 'infrastructure_ec2_asg_info', to: 'infrastructure_view#ec2_asg_info'
  get '/views/infrastructure/awsElb_info', as: 'infrastructure_elb_info', to: 'infrastructure_view#elb_info'
  get '/views/infrastructure/eksCluster_info', as: 'infrastructure_eks_cluster_info', to: 'infrastructure_view#eksCluster_info'
  get '/views/infrastructure/eksNodegroup_info', as: 'infrastructure_eks_nodegroup_info', to: 'infrastructure_view#eksNodegroup_info'
  get '/views/infrastructure/elasticacheRg_info', as: 'infrastructure_ec_repl_group_info', to: 'infrastructure_view#elasticacheRg_info'
  get '/views/infrastructure/elasticacheRedisCluster_info', as: 'infrastructure_ec_redis_cluster_info', to: 'infrastructure_view#elasticacheCluster_info'
  get '/views/infrastructure/elasticacheMemcachedCluster_info', as: 'infrastructure_ec_memcached_cluster_info', to: 'infrastructure_view#elasticacheCluster_info'
  post '/views/infrastructure/refresh_infra', as: 'refresh_infrastructure_view_infra', to: 'infrastructure_view#refresh_infra'
  post '/views/infrastructure/export_csv', as: 'export_infrastructure_csv', to: 'infrastructure_view#export_csv'
  scope :views do
    scope :infrastructure, controller: :infrastructure_view do
      get 'securityGroup_info', as: 'security_group_info', action: 'securityGroup_info'
      get 'aws_security_groups', as: 'aws_security_groups', action: 'aws_security_groups'
    end
  end

  get '/views/resiliency', as: 'resiliency_view', to: 'resiliency_view#index'
  get '/views/resiliency/aws_nodes', as: 'resiliency_view_nodes', to: 'resiliency_view#aws_nodes'
  get '/views/resiliency/ec2instance_info', as: 'resiliency_ec2_instance_info', to: 'resiliency_view#ec2instance_info'
  get '/views/resiliency/rdsAuroraInstance_info', as: 'resiliency_rds_aurora_instance_info', to: 'resiliency_view#rdsAuroraInstance_info'
  get '/views/resiliency/rdsPostgresInstance_info', as: 'resiliency_rds_postgres_instance_info', to: 'resiliency_view#rdsPostgresInstance_info'
  get '/views/resiliency/rdsMysqlInstance_info', as: 'resiliency_rds_mysql_instance_info', to: 'resiliency_view#rdsMysqlInstance_info'
  get '/views/resiliency/awsLb_info', as: 'resiliency_load_balancer_info', to: 'resiliency_view#lb_info'
  get '/views/resiliency/account_info', as: 'resiliency_account_info', to: 'resiliency_view#account_info'
  get '/views/resiliency/ecsCluster_info', as: 'resiliency_ecs_cluster_info', to: 'resiliency_view#ecsCluster_info'
  get '/views/resiliency/ecsService_info', as: 'resiliency_ecs_service_info', to: 'resiliency_view#ecsService_info'
  get '/views/resiliency/ec2Asg_info', as: 'resiliency_ec2_asg_info', to: 'resiliency_view#ec2_asg_info'
  get '/views/resiliency/awsElb_info', as: 'resiliency_elb_info', to: 'resiliency_view#elb_info'
  get '/views/resiliency/eksCluster_info', as: 'resiliency_eks_cluster_info', to: 'resiliency_view#eksCluster_info'
  get '/views/resiliency/eksNodegroup_info', as: 'resiliency_eks_nodegroup_info', to: 'resiliency_view#eksNodegroup_info'
  get '/views/resiliency/elasticacheRg_info', as: 'resiliency_ec_repl_group_info', to: 'resiliency_view#elasticacheRg_info'
  get '/views/resiliency/elasticacheRedisCluster_info', as: 'resiliency_ec_redis_cluster_info', to: 'resiliency_view#elasticacheCluster_info'
  get '/views/resiliency/elasticacheMemcachedCluster_info', as: 'resiliency_ec_memcached_cluster_info', to: 'resiliency_view#elasticacheCluster_info'
  post '/views/resiliency/refresh_infra', as: 'refresh_resiliency_view_infra', to: 'resiliency_view#refresh_infra'

  post '/infrastructure_view/update_view_configs', as: 'update_view_configs', to: 'infrastructure_view#update_view_configs'

  get '/settings', as: 'settings', to: 'settings#index'
  get '/settings/ignore_lists', as: 'ignore_lists', to: 'settings#index'

  post '/get_upload_url', as: 'get_upload_url', to: 'infrastructure_view#get_upload_url'
  post '/send_share_email', as: 'send_share_email', to: 'infrastructure_view#send_share_email'

  post '/get_upload_url', as: 'get_nw_upload_url', to: 'network_view#get_upload_url'
  post '/send_share_email', as: 'send_nw_share_email', to: 'network_view#send_share_email'

  get '/omnisearch', as: 'omnisearch', to: 'omni_search#omnisearch'
  get '/omnisearch/resources', as: 'omnisearch_resources', to: 'omni_search#search_resources'
  post '/omnisearch/resources', as: 'search_resources', to: 'omni_search#search_resources'

  # Stripe
  post '/stripe-webhook', as: 'stripe_webhook', to: 'stripe#incoming'
  post '/create-subscription', as: 'create_stripe_subscription', to: 'stripe#create_subscription'
  delete '/subscription', as: 'cancel_subscription', to: 'stripe#cancel_subscription'
  put '/subscription', as: 'change_subscription', to: 'stripe#change_subscription'
  post '/create-checkout-session', as: 'create_checkout_session', to: 'stripe#create_checkout_session'
  get '/subscription/success', as: 'subscription_success', to: 'stripe#success'
  get '/subscription/canceled', as: 'subscription_canceled', to: 'stripe#canceled'
  get '/checkout-session', as: 'checkout_session', to: 'stripe#checkout_session'
  get '/customer-portal', as: 'cusomer_portal', to: 'stripe#customer_portal'
  post '/payment_webhook', as: 'payment_webhook', to: 'stripe#payment_webhook'
  # TODO: Convert to a deep health check later
  get '/health_check', as: 'health_check', to: 'home#health_check'

  post '/save_current_resource_group', as: 'save_current_resource_group', to: 'infrastructure_view#save_current_resource_group'
  post '/save_as_new_resource_group', as: 'save_as_new_resource_group', to: 'infrastructure_view#save_as_new_resource_group'
  delete '/resource_groups', as: 'delete_resource_group', to: 'infrastructure_view#delete_resource_group'

  root to: 'accounts#index'
  unless Rails.env == 'production'
    mount Sidekiq::Web => '/sidekiq'
  end

  resources :resource_groups

  # This should ALWAYS be at the end of routes.rb
  match '*any', to: 'settings#not_found', via: [:get]
end
