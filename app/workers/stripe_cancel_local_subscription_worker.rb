class StripeCancelLocalSubscriptionWorker
  include Sidekiq::Worker

  def perform(subscription_object)
    customer_id = subscription_object["customer"]

    local_subscriptions = Subscription.where(stripe_id: customer_id)
    if local_subscriptions.count > 1
      raise StandardError.new("Duplicate stripe_ids for #{customer_id}")
    else
      local_subscription = local_subscriptions.first
    end

    local_subscription.update!({
      aws_account_quantity: 3,
      tier: "free"
    })
  end
end