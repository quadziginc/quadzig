class EmailNotificationsController < ApplicationController
  def create
    @current_user.create_email_notification_channel!(email_notification_params)
  end

  def update
    @current_user.email_notification_channel.update!(email_notification_params)
  end

  private

  def email_notification_params
    params.require(:email_notification_channel).permit(:email, :enabled)
  end
end