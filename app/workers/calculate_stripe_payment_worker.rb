class CalculateStripePaymentWorker
  include Sidekiq::Worker
  sidekiq_options queue: :payments

  def perform(user_id, account_id, days, idem_key)
    days = 1 if days == 0
    user = User.find(user_id)

    Stripe::SubscriptionItem.create_usage_record(
      user.subscription_item_id,
      {
        quantity: days,
        timestamp: DateTime.now.utc.to_i,
        action: 'increment',
      },
      {idempotency_key: idem_key}
    )

    # TODO: This is not a atomic operation.
    # Fix eventually
    current_bill = user.current_bill.to_f
    current_bill += 0.16
    user.update(current_bill: current_bill)
  end
end