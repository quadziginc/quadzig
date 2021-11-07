class StripeController < ApplicationController
  # TODO: This has mostly been taken from stripe documentation and it's not very robust right now.
  # Rewrite this with strong params etc
  # And move it to Background jobs
  skip_before_action :redirect_to_signin, :check_signed_in, :verify_authenticity_token, only: [:payment_webhook]
  # TODO: Remove this?
  skip_before_action :check_signed_in, :redirect_to_signin, only: [:incoming]

  def payment_webhook
    webhook_secret = ENV['STRIPE_WEBHOOK_SECRET']
    payload = request.body.read
    if !webhook_secret.empty?
      # Retrieve the event by verifying the signature using the raw body and secret if webhook signing is configured.
      sig_header = request.env['HTTP_STRIPE_SIGNATURE']
      event = nil

      begin
        event = Stripe::Webhook.construct_event(
          payload, sig_header, webhook_secret
        )
      rescue JSON::ParserError => e
        # Invalid payload
        render body: nil, status: 200
        return
      rescue Stripe::SignatureVerificationError => e
        # Invalid signature
        puts '⚠️  Webhook signature verification failed.'
        render body: nil, status: 200
        return
      end
    else
      data = JSON.parse(payload, symbolize_names: true)
      event = Stripe::Event.construct_from(data)
    end
    # Get the type of webhook event sent
    event_type = event['type']
    data = event['data']
    data_object = data['object']

    case event.type
    when 'customer.subscription.created'
      StripeUpdateLocalSubscriptionDetailsWorker.perform_async(data_object)
      render body: nil, status: 201
      return
    when 'customer.subscription.deleted'
      StripeCancelLocalSubscriptionWorker.perform_async(data_object)
      render body: nil, status: 201
      return
    when 'customer.subscription.updated'
      StripeUpdateLocalSubscriptionDetailsWorker.perform_async(data_object)
      render body: nil, status: 201
      return
    when 'invoice.paid'
      # Continue to provision the subscription as payments continue to be made.
      # Store the status in your database and check when a user accesses your service.
      # This approach helps you avoid hitting rate limits.
      render body: nil, status: 201
      return
    when 'invoice.payment_failed'
      # The payment failed or the customer does not have a valid payment method.
      # The subscription becomes past_due. Notify your customer and send them to the
      # customer portal to update their payment information.
    else
      puts "Unhandled event type: #{event.type}"
    end

    render body: nil, status: 200
  end

  def create_checkout_session
    data = JSON.parse(request.body.read)
    stripe_id = @current_user.subscription.stripe_id

    if stripe_id.nil?
      render json: { 'error': { message: 'Stripe ID not created yet!' } }
      return
    end
    app_host = ENV['APP_HOST']

    # See https://stripe.com/docs/api/checkout/sessions/create
    # for additional parameters to pass.
    # {CHECKOUT_SESSION_ID} is a string literal; do not change it!
    # the actual Session ID is returned in the query parameter when your customer
    # is redirected to the success page.
    begin
      session = Stripe::Checkout::Session.create(
        success_url: "https://#{app_host}/subscription/success?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "https://#{app_host}/subscription/canceled",
        payment_method_types: ['card'],
        mode: 'subscription',
        customer: stripe_id,
        line_items: [{
          adjustable_quantity: {
            enabled: true,
            minimum: 1,
            maximum: 30
          },
          quantity: 1,
          price: data['priceId'],
          description: "AWS Account"
        }],
      )
    rescue => e
      render json: { 'error': { message: e.error.message } }
      return
    end

    render json: { sessionId: session.id }
  end

  def checkout_session
    session_id = params[:sessionId]

    session = Stripe::Checkout::Session.retrieve(session_id)

    render json: session
  end

  def customer_portal
    # This is the URL to which users will be redirected after they are done
    # managing their billing.
    app_host = ENV['APP_HOST']
    return_url = "https://#{app_host}"

    session = Stripe::BillingPortal::Session.create({
      customer: @current_user.subscription.stripe_id,
      return_url: return_url
    })

    render json: { url: session.url }
  end

  # Subscription successful
  def success
  end

  # Subscription canceled
  def canceled
  end
end