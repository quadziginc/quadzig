class AuthController < ApplicationController
  skip_before_action :redirect_to_signin

  def signin
    unless params[:code]
      render :nothing => true, :status => :bad_request
      return
    end

    resp = lookup_auth_code(params[:code])
    unless resp
      redirect_to '/'
      return
    end

    ActiveRecord::Base.transaction do
      user = User.where(subscriber: resp.id_token[:sub]).first
      if user.nil?
        user = User.create(subscriber: resp.id_token[:sub],
                           email: resp.id_token[:email])

        # This usually happens when a customer signs up with email & password and then tries to
        # login/sign up again with a social provider or vice versa.
        if user.invalid? && user.errors.details[:email].any? { |detail| detail[:error] == :taken }
          render file: "#{Rails.root}/public/user_taken.html", layout: false
          return
        end
      end

      cognito_session = CognitoSession.create(user: user,
                                              expire_time: resp.id_token[:exp],
                                              issued_time: resp.id_token[:auth_time],
                                              audience: resp.id_token[:aud],
                                              refresh_token: resp.refresh_token)
      session[:cognito_session_id] = cognito_session.id
    end

    # Alternatively, you could redirect to a saved URL
    redirect_to '/'
  end

  def signout
    if cognito_session_id = session[:cognito_session_id]
      cognito_session = CognitoSession.find(cognito_session_id) rescue nil
      cognito_session.destroy if cognito_session
      session.delete(:cognito_session_id)
    end

    session[:current_queries] = nil

    redirect_to '/'
  end

  def lookup_auth_code(code)
    client = new_cognito_client()
    client.get_pool_tokens(code)
  end
end
