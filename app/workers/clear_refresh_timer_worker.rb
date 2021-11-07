class ClearRefreshTimerWorker
  include Sidekiq::Worker

  # If a user triggers a sync/refresh and the job to end the refresh_ongoing flag
  # gets lost for some reason, this jobs comes in a couple of minutes later and resets
  # the flag. Otherwise, customers might get stuck in a state where refresh_ongoing is set
  # to true indefinitely and they will not be able to trigger syncs again
  def perform
    User.where('refresh_started_at < ?', 2.minute.ago.utc).find_each do |user|
      user.update!(
        refresh_started_at: nil,
        refresh_ongoing: false
      )
    end
  end
end