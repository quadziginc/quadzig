import axios from 'axios';
import clipboard from 'clipboard';

new clipboard('.copy-btn', {
  text: function (trigger) {
    const ele = document.getElementById(trigger.dataset.clipboardTarget.replace("#", ""))
    return ele.getAttribute('href');
  }
})

function cfStackUrlFactory(regionCode, templateUrl, stackName, quadzigAccountId, externalId) {
  return `https://${regionCode}.console.aws.amazon.com/cloudformation/home?region=${regionCode}#/stacks/create/review?templateURL=${templateUrl}&stackName=${stackName}&param_QuadzigAccountId=${quadzigAccountId}&param_ExternalId=${externalId}`
}

var regionSelectionElems = document.querySelectorAll('#regionSelectionDropdownParent .dropdown-item')
regionSelectionElems.forEach((node, i) => {
  var metaTags = Array.from(document.getElementsByTagName('meta'))
  var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content

  node.addEventListener('click', (event) => {
    var regionCode = event.target.dataset.regioncode;
    var regionFullDetails = event.target.innerHTML;
    var externalId = document.getElementById("externalIdHolder").innerHTML
    var templateUrl = document.getElementById("templateUrlHolder").innerHTML
    var stackName = document.getElementById("stackNameHolder").innerHTML
    var quadzigAccountId = document.getElementById("quadzigAccountIdHolder").innerHTML
    var regionButton = document.getElementById("regionSelectionDropdownButton")
    var cfStackUrlLink = document.getElementById("cfStackUrl")
    var stackCreationRegion = document.getElementById("stackCreationRegion")

    var newHref = cfStackUrlFactory(regionCode, templateUrl, stackName, quadzigAccountId, externalId)
    cfStackUrlLink.href = newHref
    regionButton.innerHTML = regionFullDetails
    stackCreationRegion.innerHTML = regionFullDetails
  })
})


var regionSelectionStackSetElems = document.querySelectorAll('#regionSelectionDropdownParentStackset .dropdown-item')
regionSelectionStackSetElems.forEach((node, i) => {
  var metaTags = Array.from(document.getElementsByTagName('meta'))
  var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content

  node.addEventListener('click', (event) => {
    var regionCode = event.target.dataset.regioncode;
    var regionFullDetails = event.target.innerHTML;
    var regionButton = document.getElementById("regionSelectionDropdownButtonStackSet")
    var stackCreationRegion = document.getElementById("stackCreationRegionStackSet")
    var cfStackUrlLink = document.getElementById("cfStackUrlStackSet")

    var newHref = `https://${regionCode}.console.aws.amazon.com/cloudformation/home?region=${regionCode}#/stacksets/create`
    regionButton.innerHTML = regionFullDetails
    stackCreationRegion.innerHTML = regionFullDetails
    cfStackUrlLink.href = newHref
  })
})
