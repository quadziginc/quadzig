var publishableId = document.getElementById("stripe_publishable_id").innerText
var priceId = document.getElementById("stripe_price_id").innerText
var metaTags = Array.from(document.getElementsByTagName('meta'))
var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content

var createCheckoutSession = function(priceId) {
  return fetch("/create-checkout-session", {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      priceId: priceId,
      authenticity_token: csrfToken
    })
  }).then(function(result) {
    return result.json();
  });
};

document
  .getElementById("upgradeSubscription")
  .addEventListener("click", function(evt) {
    createCheckoutSession(priceId).then(function(data) {
      // Call Stripe.js method to redirect to the new Checkout page
      let stripe = Stripe(publishableId);
      stripe
        .redirectToCheckout({
          sessionId: data.sessionId
        })
    });
  });
