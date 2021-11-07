require 'search_parser_utils'

class OmniSearchController < ApplicationController
  include Elasticsearch::DSL

  def omnisearch
    # TODO: Explicit. Required?
    @resources = nil
    @current_queries = session[:current_queries]
  end

  # TODO: We probably need some kind of lightweight rate limiting
  # for this method.
  def search_resources
    @search_string = search_params["search_string"]

    if @search_string.strip.to_s == ""
      redirect_to omnisearch_path
      return
    end

    begin
      tree = SearchParser.new.parse(@search_string)
      es_query = ESTransform.new.apply(tree)
      es_query[:query][:bool][:must].append({
        match: {user_id: @current_user.id}
      })
    rescue Parslet::ParseFailed => e
      combined_search_string = "#{@search_string} #{@current_user.id}"
      es_query = search do
        query do
          simple_query_string do
            # You can't have any kind of evaluation here.
            # For example, you can't have "#{@search_string} #{@current_user.id}" here
            # it will silently fail and quer will be empty
            query combined_search_string
            fields ['user_id^100', '*']
            default_operator 'or'
            lenient true
          end
        end
      end
    end

    session[:current_queries] = session[:current_queries] || []
    session[:current_queries].prepend(@search_string)
    session[:current_queries] = session[:current_queries].uniq
    if session[:current_queries].count > 20
      session[:current_queries].pop()
    end

    @current_queries = session[:current_queries]

    routing_key = @current_user.id
    page = params[:page].to_i || 1
    size = 20
    from = page > 1 ? (((page - 1) * size) + 1) : 0
    begin
      results = EsClient.search body: es_query.to_json,
                                index: 'cloud_resources',
                                routing: routing_key,
                                from: from,
                                size: size,
                                expand_wildcards: :none,
                                timeout: '5s'
    rescue StandardError => e
      @omnisearch_error = true
      render :omnisearch
      return
    end

    hits = results.fetch('hits', {}).fetch('hits', [])
    total_count = results.dig('hits', 'total', 'value') || 0
    @pagy_array, hits = pagy_array(hits, items: size, count: total_count)

    query_details = hits.map do |hit|
      {
        id: hit["_id"],
        rt: hit["_source"]["rt"]
      }
    end

    grouped_query_details = query_details.group_by { |qd| qd[:rt] }
    @account_info = @current_user.aws_accounts.inject({}) do |info, account|
      info[account.id] = {
        account_id: account.account_id,
        account_name: account.name
      }

      info
    end

    @accounts = @current_user.aws_accounts

    if @current_user.subscription.tier.to_s == "free" && @current_user.aws_accounts.where(creation_complete: true).count >= 3
      if !@current_user.in_early_access_period?
        @accounts = @current_user.aws_accounts.limit(3)
      elsif @current_user.in_early_access_period?
        @accounts = @current_user.aws_accounts
      end
    end

    @allowed_ent_aws_account_quantity = @current_user.subscription.aws_account_quantity + 3

    if (@current_user.subscription.tier.to_s == "enterprise" && (@current_user.aws_accounts.where(creation_complete: true).count >= @allowed_ent_aws_account_quantity))
      @accounts = @current_user.aws_accounts.limit(@allowed_ent_aws_account_quantity)
    end

    @resources = []
    grouped_query_details.each do |resource_type, resource_info|
      ids = resource_info.map { |r| r[:id] }
      if resource_type == "tgw_attachment"
        @resources.concat AwsTgwAttachment.where(aws_account: @accounts, id: ids)
      elsif resource_type == "ecs_cluster"
        @resources.concat AwsEcsCluster.where(aws_account: @accounts, id: ids)
      elsif resource_type == "vpc"
        @resources.concat AwsVpc.where(aws_account: @accounts, id: ids)
      elsif resource_type == "tgw"
        @resources.concat AwsTgw.where(aws_account: @accounts, id: ids)
      elsif resource_type == "subnet"
        @resources.concat AwsSubnet.where(aws_account: @accounts, id: ids)
      elsif resource_type == "ngw"
        @resources.concat AwsNgw.where(aws_account: @accounts, id: ids)
      elsif resource_type == "load_balancer"
        @resources.concat AwsLoadBalancer.where(aws_account: @accounts, id: ids)
      elsif resource_type == "igw"
        @resources.concat AwsIgw.where(aws_account: @accounts, id: ids)
      elsif resource_type == "ecs_service"
        @resources.concat AwsEcsService.where(aws_account: @accounts, id: ids)
      elsif resource_type == "ec2_instance"
        @resources.concat AwsEc2Instance.where(aws_account: @accounts, id: ids)
      elsif resource_type == "rds_instance"
        @resources.concat AwsRdsDbInstance.where(aws_account: @accounts, id: ids)
      elsif resource_type == "aurora_cluster"
        @resources.concat AwsRdsAuroraCluster.where(aws_account: @accounts, id: ids)
      elsif resource_type == "peering_connection"
        @resources.concat AwsPeeringConnection.where(aws_account: @accounts, id: ids)
      elsif resource_type == "rds_aurora_instance"
        @resources.concat AwsRdsAuroraDbInstance.where(aws_account: @accounts, id: ids)
      elsif resource_type == "ec2_asg"
        @resources.concat AwsEc2Asg.where(aws_account: @accounts, id: ids)
      elsif resource_type == "elb"
        @resources.concat AwsElb.where(aws_account: @accounts, id: ids)
      elsif resource_type == "eks_cluster"
        @resources.concat AwsEksCluster.where(aws_account: @accounts, id: ids)
      elsif resource_type == "eks_nodegroup"
        @resources.concat AwsEksNodegroup.where(aws_account: @accounts, id: ids)
      elsif resource_type == "elasticache_node"
        @resources.concat AwsElasticacheCluster.where(aws_account: @accounts, id: ids)
      end
    end

    @resources = @resources.sort_by { |r| query_details.index { |q| r.id == q[:id] } }
    render :omnisearch
  end

  private

  def search_params
    params.permit(:search_string)
  end

  def pagy_array(array, vars = {})
    pagy, _array = super
    [pagy, array[0, pagy.items]]
  end
end
