import axios from 'axios';

var metaTags = Array.from(document.getElementsByTagName('meta'))
var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content

function fetchAndShowQrCode() {
  var mfaQrCodeContainer = document.getElementById("mfaQrCodeContainer")
  mfaQrCodeContainer.innerHTML = '<div class="align-self-center spinner-border" role="status"><span class="sr-only">Loading...</span></div>'
  axios.post("/preferences/generate_mfa_qr_code", {
    authenticity_token: csrfToken
  }).then((resp) => {
    let qrCodeImage = document.createElement('img');
    qrCodeImage.setAttribute('src',`data:image/png;base64, ${resp.data.data}`)
    mfaQrCodeContainer.innerHTML = ""
    mfaQrCodeContainer.appendChild(qrCodeImage)

    const secretCode = resp.data.secret_code
    var mfaSecretCodeContainer = document.getElementById("mfaSecretCodeContainer")
    let secretCodeNode = document.createTextNode(resp.data.secret_code);
    mfaSecretCodeContainer.innerHTML = ""
    mfaSecretCodeContainer.appendChild(secretCodeNode)
  })
}

const activateMfa = document.getElementById('activateMfa')
const showSecretCode = document.getElementById('showSecretCode')

if (activateMfa){
  document.getElementById('activateMfa').addEventListener('click', (e) => {
    fetchAndShowQrCode()
  })
}

if (showSecretCode){
  document.getElementById('showSecretCode').addEventListener('click', (e) => {
    fetchAndShowQrCode()
  })
}
