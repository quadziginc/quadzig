class StripeUserCreationWorker
  include Sidekiq::Worker
  sidekiq_options queue: :payments

  # Keep this job as simple as possible. Don't add more functionality here
  # This worker should only create a stripe customer and nothing else
  def perform(user_id, idem_key)
    user = User.find(user_id)
    customers = Stripe::Customer.list(email: user.email)

    # TODO: What happens if this is greater than 1?
    if customers.data.count >= 1
      raise StandardError.new("Stripe already has a subscription for this user!")
    else
      customer = Stripe::Customer.create(
        {email: user.email},
        {idempotency_key: idem_key}
      )
    end

    user.subscription.update!(stripe_id: customer.id)
  end
end