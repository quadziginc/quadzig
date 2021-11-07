class SettingsController < ApplicationController
  def update_ignore_lists
    updated = @current_user.update(
      ignored_aws_vpcs: (ignore_lists_params[:ignored_aws_vpcs]).split(",").map { |v| v.strip },
      # ignored_aws_subnets: (ignore_lists_params[:ignored_aws_subnets]).split(",").map { |s| s.strip },
      ignore_default_vpcs: ignore_lists_params[:ignore_default_vpcs]
    )
    unless updated
      @current_user.errors.messages.each do |field, errors|
        flash.now[field] = errors
      end
    end
    render :index
  end

  def delete_mfa_device
    cognito_client = Aws::CognitoIdentityProvider::Client.new(region: ENV['AWS_DEFAULT_REGION'])
    session_id = session[:cognito_session_id]
    cognito_session = @current_user.cognito_sessions.find(session_id)
    client = CognitoClient.new
    resp = client.refresh_id_token(cognito_session.refresh_token)
    access_token = resp.cognito_access_token

    cognito_client.set_user_mfa_preference({
      software_token_mfa_settings: {
        enabled: false,
        preferred_mfa: false
      },
      access_token: access_token
    })
    @current_user.mfa_device.destroy!
    redirect_to preferences_path
  end

  def generate_mfa_qr_code
    # TODO: So many things can go wrong here...
    # Refactor this.
    cognito_client = Aws::CognitoIdentityProvider::Client.new(region: ENV['AWS_DEFAULT_REGION'])
    session_id = session[:cognito_session_id]
    cognito_session = @current_user.cognito_sessions.find(session_id)
    client = CognitoClient.new
    resp = client.refresh_id_token(cognito_session.refresh_token)
    access_token = resp.cognito_access_token
    resp = cognito_client.associate_software_token({access_token: access_token})
    secret_code = resp.secret_code
    encoded_secret_code = "otpauth://totp/Quadzig:#{@current_user.email}?secret=#{secret_code}&issuer=Quadzig"
    qrcode = RQRCode::QRCode.new(encoded_secret_code)
    file_name = SecureRandom.uuid
    png = qrcode.as_png(
      bit_depth: 1,
      border_modules: 4,
      color_mode: ChunkyPNG::COLOR_GRAYSCALE,
      color: 'black',
      file: nil,
      fill: 'white',
      module_px_size: 6,
      resize_exactly_to: false,
      resize_gte_to: false,
      size: 240
    )

    IO.binwrite("/tmp/#{file_name}.png", png.to_s)
    
    json = {}
    json["filename"] = file_name
    json["content_type"] = 'image/png'
    json["data"] = Base64.encode64(File.read("/tmp/#{file_name}.png"))
    json["secret_code"] = secret_code
    render json: json
  end

  def configure_mfa
    cognito_client = Aws::CognitoIdentityProvider::Client.new(region: ENV['AWS_DEFAULT_REGION'])
    mfa_code = configure_mfa_params[:mfa_code]
    mfa_device_name = configure_mfa_params[:mfa_device_name]

    if !(/[0-9]{6,8}/ =~ mfa_code)
      flash[:mfa_errors] = ["Invalid MFA Code format! Please enter a valid MFA Code."]
      redirect_to preferences_path
      return
    end
    session_id = session[:cognito_session_id]
    cognito_session = @current_user.cognito_sessions.find(session_id)
    client = CognitoClient.new
    resp = client.refresh_id_token(cognito_session.refresh_token)
    access_token = resp.cognito_access_token

    begin
      cognito_client.verify_software_token({
        access_token: access_token,
        user_code: mfa_code, # required
        friendly_device_name: "MFA Device",
      })
    rescue Aws::CognitoIdentityProvider::Errors::EnableSoftwareTokenMFAException
      flash[:mfa_errors] = ["Invalid MFA Code format! The MFA Code you entered did not match with the scanned QR Code/Secret String. Please try again."]
      redirect_to preferences_path
      return
    end

    # If this fails for whatever reason, mfa process is still not complete yet
    mfa_device = @current_user.create_mfa_device(device_name: mfa_device_name)
    if !mfa_device.valid?
      if mfa_device.errors.details[:device_name].any? { |d| d[:error] == :invalid }
        flash[:mfa_errors] = ["Invalid MFA Device Name! Device Names can only contain alphabets, numbers, underscores, hyphens & spaces. Please try again."]
        redirect_to preferences_path
        return
      end
    end

    resp = cognito_client.set_user_mfa_preference({
      software_token_mfa_settings: {
        enabled: true,
        preferred_mfa: true
      },
      access_token: access_token
    })

    redirect_to preferences_path
  end

  def preferences
    @mfa_device = @current_user.mfa_device
    stripe_id = @current_user.subscription.stripe_id
    if stripe_id.nil?
      @user_not_setup_yet = true
      @tags = ["free"]
      @tags << "early-access" if $Emails.include? @current_user.email
      @aws_accounts_count = @current_user.aws_accounts.where(creation_complete: true).count
      @current_user.subscription.update!(
        tier: "free",
        aws_account_quantity: 3
      )
    else
      resp = Stripe::Subscription.list({
        customer: stripe_id
      })

      subscriptions = resp["data"]
      if subscriptions.count > 1
        raise StandardError.new("More than one subscription found for user #{stripe_id.inspect}")
      elsif subscriptions.count == 1
        @current_user.subscription.update!(
          tier: "enterprise",
          aws_account_quantity: subscriptions[0]["quantity"]
        )
      elsif subscriptions.count == 0
        @tags = ["free"]
        @tags << "early-access" if $Emails.include? @current_user.email
        @aws_accounts_count = @current_user.aws_accounts.where(creation_complete: true).count
        @current_user.subscription.update!(
          tier: "free",
          aws_account_quantity: 3
        )
      end
    end
    @subscription = @current_user.subscription
  end

  def notifications
  end

  private

  def ignore_lists_params
    params.require(:user).permit(:ignored_aws_vpcs, :ignore_default_vpcs)
  end

  def configure_mfa_params
    params.permit(:mfa_code, :mfa_device_name)
  end
end
