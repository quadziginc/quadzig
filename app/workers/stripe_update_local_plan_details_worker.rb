class StripeUpdateLocalPlanDetailsWorker
  include Sidekiq::Worker

  def perform(data_object)
    customer_id = data_object["customer"]
    local_subscriptions = Subscription.where(stripe_id: customer_id)
    if local_subscriptions.count > 1
      raise StandardError.new("Duplicate stripe_ids for #{customer_id}")
    else
      local_subscription = local_subscriptions.first
    end
    resp = Stripe::Subscription.list({
      customer: customer_id
    })

    subscriptions = resp["data"]
    if subscriptions.count > 1
      raise StandardError.new("More than one subscription found for customer #{customer_id}")
    elsif subscriptions.count == 1
      subscription = subscriptions[0]
      quantity = subscription["quantity"]

      local_subscription.update!({
        aws_account_quantity: quantity,
        tier: "enterprise"
      })
    end
  end
end