class ViewsController < ApplicationController
  # TODO: Why are we doing this?
  skip_before_action :verify_authenticity_token, only: [:send_share_email]
  before_action :set_sidebar_status, :set_footer_status

  def account_info
    aws_account_id = aws_account_id_param

    @account = @current_user.aws_accounts.find(aws_account_id)
    render partial: "aws_account_info"
  end

  def region_info
    render status: 501
  end

  def update_view_configs
    update_params = update_view_config_params
    account = @current_user.aws_accounts.find(update_params[:accountId])
    resourceId = update_params[:resourceId]

    if update_params[:nodeType] == 'ecsCluster'
      resource = AwsEcsCluster.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'vpc'
      resource = AwsVpc.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'tgw'
      resource = AwsTgw.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'subnet'
      resource = AwsSubnet.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'ngw'
      resource = AwsNgw.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'awsLb'
      resource = AwsLoadBalancer.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'igw'
      resource = AwsIgw.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'ecsService'
      resource = AwsEcsService.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'ec2instance'
      resource = AwsEc2Instance.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'rdsMysqlInstance'
      resource = AwsRdsDbInstance.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'rdsPostgresInstance'
      resource = AwsRdsDbInstance.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'AwsRdsDbInstance'
      resource = AwsRdsAuroraDbInstance.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'ec2Asg'
      resource = AwsEc2Asg.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'awsElb'
      resource = AwsElb.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'eksNodegroup'
      resource = AwsEksNodegroup.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'peering'
      resource = AwsPeeringConnection.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'tgwattch'
      resource = AwsTgwAttachment.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'eksCluster'
      resource = AwsEksCluster.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'elasticacheCluster'
      resource = AwsElasticacheCluster.where(id: resourceId, aws_account: @current_user.aws_accounts).first
    elsif update_params[:nodeType] == 'account'
      resource = @current_user.aws_accounts.find(resourceId)
    end

    unless resource.nil?
      resource.view_config['displayLabel'] = update_params[:newLabel] if update_params[:newLabel]
      if update_params[:annotations].present?
        if update_params[:annotations].length > 1000
          flash[:errors] = ['Exceeds Annotations Length']
        else
          resource.view_config['annotations'] = update_params[:annotations]
        end
      end
      resource.save
    end
  end

  def refresh_infra
    if !@current_user.refresh_ongoing || Rails.env == "development"
      @current_user.aws_accounts.each do |account|
        account.active_regions.each do |region_code|
          [
            'PopulateAwsVpcsWorker',
            'PopulateAwsSubnetsWorker',
            'PopulateAwsPeeringConnsWorker',
            'PopulateAwsTransitGatewaysWorker',
            'PopulateTgwAttachmentsWorker',
            'PopulateAwsIgwsWorker',
            'PopulateAwsNgwsWorker',
            'PopulateAwsEc2InstancesWorker',
            'PopulateAwsDbInstancesWorker',
            'PopulateAwsAuroraInstancesWorker',
            'PopulateAwsLoadBalancersWorker',
            'PopulateEcsClustersWorker',
            'PopulateAwsEcsServicesWorker',
            'PopulateAwsEc2AsgsWorker',
            'PopulateAwsElbsWorker',
            'PopulateAwsEksResourcesWorker',
            'PopulateAwsElasticacheClusterWorker',
            'PopulateAwsElasticacheReplicationGroupsWorker'
          ].each do |worker_class|
            worker_class.constantize.perform_async(@current_user.id, account.id, region_code)
          end
        end
      end

      @current_user.update(
        refresh_ongoing: true,
        refresh_started_at: DateTime.now.utc
      )
      EndResourceRefreshWorker.perform_in(30.seconds, @current_user.id)
    end

    render body: nil, status: 201
  end

  def get_upload_url
    # TODO: This is a slow operation. One of the below would be a better method.
    # 1. Push this to a background job and let the client async request the url(complex)
    # 2. Batch Generate presigned url with long validity and store them in DB. Just fetch and
    # return at run time(easy. But has to be closely monitored and a fallback implemented as well
    # if we run out of pre-generated URLs).
    key = "#{SecureRandom.alphanumeric(10)}.png"
    if $S3_RESOURCE.blank?
      $S3_RESOURCE = Aws::S3::Resource.new(region: ENV['AWS_DEFAULT_REGION'])
    end
    object = $S3_RESOURCE.bucket(ENV['SHARE_S3_BUCKET']).object(key)
    url = URI.parse(object.presigned_url(:put, expires_in: 30))
    render json: {
      url: url,
      fileName: key
    }
  end

  def send_share_email
    email = share_email_params[:email]
    filename = share_email_params[:fileName]
    # TODO: Is this safe?
    if $S3_RESOURCE.blank?
      $S3_RESOURCE = Aws::S3::Resource.new(region: ENV['AWS_DEFAULT_REGION'])
    end
    object = $S3_RESOURCE.bucket(ENV['SHARE_S3_BUCKET']).object(filename)
    url = URI.parse(object.presigned_url(:get, expires_in: 86400))
    mail = UsersMailer.share_arch(url.to_s, email)
    mail.deliver_later
  end

  private

  def update_view_config_params
    params.permit(:nodeType, :resourceId, :accountId, :newLabel, :annotations)
  end

  def share_email_params
    params.require(:send_email_params).permit(:email, :fileName)
  end

  def region_params
    params.require(:region_codes)
  end

  def aws_account_id_param
    params.require(:account_id)
  end

  def set_sidebar_status
    @show_sidebar = false
  end

  def set_footer_status
    @show_footer = false
  end
end
