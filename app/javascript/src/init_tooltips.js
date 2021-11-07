coreui = require("coreui.bundle.min")

window.addEventListener('load', function () {
  var icons = Array.from(document.getElementsByClassName('add-tooltip'))
  Array.from(icons).map(i => new coreui.Tooltip(i, {boundary: 'window'}))
})

window.addEventListener('showInfoPanel', function() {
  var icons = Array.from(document.getElementsByClassName('add-tooltip'))
  Array.from(icons).map(i => new coreui.Tooltip(i, {boundary: 'window'}))
})