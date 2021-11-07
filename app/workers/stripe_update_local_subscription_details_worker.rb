class StripeUpdateLocalSubscriptionDetailsWorker
  include Sidekiq::Worker

  def perform(subscription_object)

    customer_id = subscription_object["customer"]
    quantity = subscription_object["quantity"]

    local_subscriptions = Subscription.where(stripe_id: customer_id)
    if local_subscriptions.nil?
      raise StandardError.new("Can't find customer with customer id #{customer_id}")
    elsif local_subscriptions.count > 1
      raise StandardError.new("Duplicate stripe_ids for #{customer_id}")
    else
      local_subscription = local_subscriptions.first
    end

    if quantity == 0
      local_subscription.update!({
        aws_account_quantity: 3,
        tier: "free"
      })
    else
      local_subscription.update!({
        aws_account_quantity: quantity,
        tier: "enterprise"
      })
    end
  end
end