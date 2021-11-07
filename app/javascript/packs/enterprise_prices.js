var metaTags = Array.from(document.getElementsByTagName('meta'))
var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content

document.getElementById("manageBilling").addEventListener('click', function(e) {
  e.preventDefault();
  fetch('/customer-portal')
    .then((response) => response.json())
    .then((data) => {
      window.location.href = data.url;
    })
    .catch((error) => {
      console.error('Error:', error);
    });
});