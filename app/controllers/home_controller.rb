# TODO: This controller does too many things right now. Break it up
class HomeController < ApplicationController
  skip_before_action :redirect_to_signin, only: [:health_check]

  def health_check
    # TODO: Convert to deep check later
    render json: {}, status: :ok
  end

  # Simple endpoint to test sentry integration
  def error
    1/0
  end

  private
end
