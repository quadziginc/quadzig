class AccountsController < ApplicationController
  def index
    @id = session.id
    if params[:from_account_creation]
      @from_account_creation = true
    end

    @accounts = @current_user.aws_accounts
    @creation_completion_accounts = @current_user.aws_accounts.where(creation_complete: true)

    if @current_user.subscription.tier.to_s == "free" && @current_user.aws_accounts.where(creation_complete: true).count > 3
      if !@current_user.in_early_access_period?
        flash[:errors] = ["You have exceeded the free tier limit. Visualization views & Omnisearch will only work across 3 AWS Accounts as part of free tier."]
      end
    end

    @subscription = @current_user.subscription
    @allowed_ent_aws_account_quantity = @subscription.aws_account_quantity + 3
    if (@current_user.subscription.tier.to_s == "enterprise" && (@current_user.aws_accounts.where(creation_complete: true).count >= @allowed_ent_aws_account_quantity))
      @subscription_limit_reached = true
    end
  end

  def new
    # TODO: Fragile. Move to some kind of centralized checking
    @subscription = @current_user.subscription
    if @current_user.subscription.tier.to_s == "free" && @current_user.aws_accounts.where(creation_complete: true).count >= 3
      if !@current_user.in_early_access_period?
        flash.alert = "You have reached the limit of Free Tier. Please upgrade your subscription to visualize more AWS Accounts."
        redirect_to preferences_path
      end
    elsif (@current_user.subscription.tier.to_s == "enterprise" && (@current_user.aws_accounts.count >= (@subscription.aws_account_quantity + 3)))
      flash.alert = "You have reached the limit of your Enterprise Subscription. Please upgrade your subscription to visualize more AWS Accounts."
      redirect_to preferences_path
    end
    @cf_stack_name = "Quadzig-secure-access-#{SecureRandom.hex(8)}"
    @cf_link = CfTemplateVersion.where(is_latest: true).first.cf_link
    @external_id = SecureRandom.hex(20)
    @regions = AwsRegion.all
    user_id = @current_user.id
    @quadzig_account_id = ENV['QUADZIG_ACCOUNT_ID']
    APP_REDIS_POOL.with do |client|
      # 1 day
      client.set(@external_id, user_id, ex: 86400)
    end
  end

  def delete
    account = @current_user.aws_accounts.unscoped.find(account_del_params[:id])
    account.destroy!
    redirect_to aws_accounts_path
  end

  def show
    @account = @current_user.aws_accounts.find(params[:id])
  end

  def update
    # Careful here. Users might be able to edit params of other accounts
    # if we don't scope properly
    @account = @current_user.aws_accounts.find(params[:id])
    if @account.update(account_update_params)
      render :show
    else
      @account.errors.messages.each do |field, errors|
        flash.now[field] = errors
      end
      render :show
    end
  end

  def update_cf
    @account = @current_user.aws_accounts.find(params[:id])
    @latest_cf_version = CfTemplateVersion.where(is_latest: true).first
  end

  private

  def account_params
    # TODO: This should be aws_account. Not :account
    params.require(:account).permit(
      :external_id
    )
  end

  def account_del_params
    params.permit(:id)
  end

  def account_update_params
    params.require(:aws_account).permit(:id, :name, active_regions: [])
  end

  def acccount_creation_params
    params.permit(:externalId)
  end
end
