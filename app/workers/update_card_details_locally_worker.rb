class UpdateCardDetailsLocallyWorker
  include Sidekiq::Worker

  def perform(user_id)
    user = User.find(user_id)
    subscription = user.subscription

    resp = Stripe::PaymentMethod.retrieve(
      subscription.payment_id
    )

    subscription.update!(
      last_card_digits: resp.card.last4,
      card_expiry_month: resp.card.exp_month,
      card_expiry_year: resp.card.exp_year,
      card_brand: resp.card.brand
    )
  end
end