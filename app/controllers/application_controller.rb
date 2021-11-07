require 'cognito_jwt_keys'
require 'cognito_client'

class ApplicationController < ActionController::Base
  include Pagy::Backend
  before_action :check_signed_in, :redirect_to_signin, :set_sidebar_status, :set_footer_status,
                :set_outdated_cf_template_status

  def append_info_to_payload(payload)
      super
      payload[:host] = request.host
      payload[:remote_ip] = request.remote_ip
      payload[:ip] = request.ip
      payload[:sub_id] = @current_user.try(:subscriber)
  end

  def redirect_to_signin
    unless @current_user
      redirect_to signin_path
    end
  end

  def check_signed_in
    @is_signed_in = false
    @current_user = nil
    @cognito_session = nil

    cognito_session = nil
    if session[:cognito_session_id]
      begin
        cognito_session = CognitoSession.find(session[:cognito_session_id])
      rescue ActiveRecord::RecordNotFound
      end
    end

    unless cognito_session
      return
    end

    now = Time.now.tv_sec

    if cognito_session.expire_time > now
      # Still valid, use
      @is_signed_in = true
      @current_user = cognito_session.user
      @cognito_session = cognito_session
      return
    end

    # Need to refresh token
    if refresh_cognito_session(cognito_session)
      @is_signed_in = true
      @current_user = cognito_session.user
      @cognito_session = cognito_session
      return
    end
  end

  def refresh_cognito_session(cognito_session)
    client = new_cognito_client()

    resp = client.refresh_id_token(cognito_session.refresh_token)

    return false unless resp

    cognito_session.expire_time = resp.id_token[:exp]
    cognito_session.issued_time = resp.id_token[:auth_time]
    cognito_session.audience = resp.id_token[:aud]

    cognito_session.save!
  end

  def set_outdated_cf_template_status
    # To make sure that health checks don't fail
    if @current_user
      @outdated_cf_template = @current_user.aws_accounts.any? { |account| !account.cf_template_version.is_latest }
      @latest_cf_template = CfTemplateVersion.where(is_latest: true).first
    end
    @notifications = Notification.active.web
  end

  def new_cognito_client
    CognitoClient.new(:redirect_uri => auth_sign_in_url)
  end

  def not_found
    render file: "public/404.html", layout: false
  end

  private

  def set_sidebar_status
    @show_sidebar = true
  end

  def set_footer_status
    @show_footer = true
  end

  def check_subscription_eligibility!
    return true if @current_user.subscription_enterprise?

    # TODO: Do feature level details dynamically
    error_response = { error: 'User is not Enterprise User', error_code: 100, modal_id: 'upgradeTierModal' }
    error_details = t("views.check_subscription_eligibility!.#{action_name}")
    error_response.merge!(error_details) if error_details
    render status: 401, json: error_response
  end
end
