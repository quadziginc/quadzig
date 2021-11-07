class EndResourceRefreshWorker
  include Sidekiq::Worker

  def perform(user_id)
    user = User.find(user_id)
    user.update(
      refresh_ongoing: false,
      refresh_started_at: nil
    )
  end
end