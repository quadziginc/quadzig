import cytoscape from 'cytoscape';
import edgehandles from 'cytoscape-edgehandles';
import popper from 'cytoscape-popper';
import fcose from 'cytoscape-fcose';
import cyCanvas from 'cytoscape-canvas';
import nodeEditing from 'cytoscape-node-editing';
import expandCollapse from 'cytoscape-expand-collapse';
import gridGuide from 'cytoscape-grid-guide';
import typeahead from 'corejs-typeahead';
import fuzzysort from 'fuzzysort';
import axios from 'axios';
import konva from 'konva';

// TODO: Upgrade context menu extension to 4.1.0
// Safari Bug details - https://github.com/iVis-at-Bilkent/cytoscape.js-context-menus/issues/55
import $ from 'jquery';
import contextMenus from 'cytoscape-context-menus';
import { saveAs } from "file-saver";

import small_sidebar_icon from 'images/generic_icons/small_sidebar.svg';
import medium_sidebar_icon from 'images/generic_icons/medium_sidebar.svg';
import large_sidebar_icon from 'images/generic_icons/large_sidebar.svg';
import ecs_service_logo from 'images/aws_icons/ecs_service.png';
import eks_service_logo from 'images/aws_icons/eks_service.png'
import eks_cluster_logo from 'images/aws_icons/eks_service.png'
import asg_logo from 'images/aws_icons/asg.png';

import 'cytoscape-context-menus/cytoscape-context-menus.css';

interceptAxios();

cyCanvas(cytoscape)
cytoscape.use(fcose);
cytoscape.use(edgehandles);
nodeEditing( cytoscape, $, konva );
cytoscape.use(popper);
cytoscape.use(contextMenus, $);

expandCollapse(cytoscape)
gridGuide( cytoscape );

var savedRemovedNodesState = {
  'vpc': null,
  'subnet': null,
  'igw': null,
  'ngw': null,
  'tgw': null,
  'us-east-2': null,
  'us-east-1': null,
  'us-west-1': null,
  'us-west-2': null,
  'ap-south-1': null,
  'ap-northeast-2': null,
  'ap-southeast-1': null,
  'ap-southeast-2': null,
  'ap-northeast-1': null,
  'ca-central-1': null,
  'eu-central-1': null,
  'eu-west-1': null,
  'eu-west-2': null,
  'eu-west-3': null,
  'eu-north-1': null,
  'sa-east-1': null,
  'ec2instance': null,
  'awsLb': null,
  'rdsMysqlInstance': null,
  'rdsPostgresInstance': null,
  'ecsService': null,
  'ecsCluster': null
}

// Don't judge me. Normal classes were not working after downgrading
// from 4.1.0 to 3.1.0
// TODO: Fix/Upgrade to 4.1.0 and remove this abomination
function addStyle(styleString) {
  const style = document.createElement('style');
  style.textContent = styleString;
  document.head.append(style);
}

addStyle(`.cxt-menu {
  font-family: 'Open Sans';
  border-radius: 5px;
  background-color: #fff;
}`)

addStyle(`.cxt-menu-item {
  background-color: #fff;
  color: black;
  font-family: -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Helvetica Neue",Arial,"Noto Sans",sans-serif,"Apple Color Emoji","Segoe UI Emoji","Segoe UI Symbol","Noto Color Emoji";
}`)

addStyle(`.cxt-menu-item:hover {
  background-color: #CED2D8;
  color: black;
}`)

// ---------------------------------------------
// Start Filter Sidebar Behavior
// ---------------------------------------------

document.getElementById("showAllRegions").addEventListener('change', function(event) {
  document.querySelectorAll('.showRegions').forEach((inp, i) => {
    if (inp.checked != event.target.checked) {
      inp.click()
    }
  })
})

document.getElementById("showAllAccounts").addEventListener('change', function(event) {
  document.querySelectorAll('.showAccounts').forEach((inp, i) => {
    if (inp.checked != event.target.checked) {
      inp.click()
    }
  })
})

const accountCheckboxes = document.querySelectorAll(".showAccounts");
accountCheckboxes.forEach((node, i) => {
  node.addEventListener('change', (cbEvent) => {
    var visibility = cbEvent.target.checked;
    var accountId = cbEvent.target.dataset["account"]
    toggleSingleNodeVisibility(accountId, visibility)
  })
})

const regionCheckboxes = document.querySelectorAll(".showRegions");
regionCheckboxes.forEach((node, i) => {
  node.addEventListener('change', (cbEvent) => {
    var visibility = cbEvent.target.checked;
    var regionCode = cbEvent.target.dataset["region"]
    toggleRegionVisibility(regionCode, visibility)
  })
})

export function toggleVisibility(nodeType, visible) {
  if (visible && savedRemovedNodesState[nodeType]) {
    (savedRemovedNodesState[nodeType]).restore()
  } else {
    savedRemovedNodesState[nodeType] = cy.nodes(`[nodeType="${nodeType}"]`).remove()
  }
}

export function toggleSingleNodeVisibility(nodeId, visible) {
  if (visible && savedRemovedNodesState[nodeId]) {
    (savedRemovedNodesState[nodeId]).restore()
  } else {
    savedRemovedNodesState[nodeId] = cy.$id(nodeId).remove()
  }
}

export function toggleRegionVisibility(regionCode, visible) {
  if (visible && savedRemovedNodesState[regionCode]) {
    (savedRemovedNodesState[regionCode]).restore()
  } else {
    savedRemovedNodesState[regionCode] = cy.nodes(`[id *= "${regionCode}"]`).remove()
  }
}
export function showUpgradeTierModal(domId = 'upgradeTierModal', data = {}){
  let parentId = ".modal#" + domId
  if (( data !== undefined) && (Object.keys(data).length > 0)){
    document.querySelector(parentId + ' .modal-header h3').innerHTML = data.header
    if (data.image){
      document.querySelector(parentId + ' .modal-body img').src  = data.image
      document.querySelector(parentId + ' .modal-body img').style.display = '';
    }else{
      document.querySelector(parentId + ' .modal-body img').style.display = 'none';
    }
    document.querySelector(parentId + ' .modal-body p.text-center').innerHTML = data.body
  }
  let existing_open_modal = document.querySelector('.modal.show')
  if (existing_open_modal !== null) {
    let existing_modal = coreui.Modal.getInstance(document.querySelector('.modal.show'))
    existing_modal.hide();
  }
  // upgrade tier modal
  let modal = new coreui.Modal(document.getElementById(domId))
  modal.show();
}

export function interceptAxios(){
  axios.interceptors.response.use(undefined, function (error) {
    let data = error.response.data;
    if (data.error_code === 100) {
      showUpgradeTierModal(data.modal_id, data.dialog);
    }
    return Promise.reject(error);
  });
}

// ---------------------------------------------
// Start View Search
// ---------------------------------------------

window.addEventListener('searchIdsReady', function() {
  function keydown(evt){
    if (!evt) evt = event;
    if ((evt.ctrlKey && evt.keyCode===70) || (evt.metaKey && evt.keyCode===70)){
      evt.preventDefault();
      document.getElementById('findResource').value = "";
      searchBarModal.show();
    } else if (evt.keyCode === 27) {
      window.edgeHandlesApi.stop()
    }
  }

  document.getElementById('searchBarModal').addEventListener('shown.coreui.modal', () => {
    document.getElementById('findResource').focus()
  })

  document.onkeydown = keydown;

  var searchBarModal = new coreui.Modal(document.getElementById('searchBarModal'), {
    keyboard: false
  })

  var substringMatcher = function(strs) {
    return function findMatches(q, cb) {
      var matches;

      // an array that will be populated with substring matches
      matches = [];
      var results = fuzzysort.go(q, strs, {key: 'resourceId'})
      matches = results.map((r) => {
        return {
          resourceId: r.target,
          searchableId: r.obj.searchableId
        }
      })

      cb(matches);
    };
  };

  $('#findResource').typeahead({
    classNames: {
      menu: 'card w-100'
    },
    hint: true,
    highlight: true,
    minLength: 1
  },{
    name: 'bhAwsResources',
    source: substringMatcher(window.resourceIdsForSearch),
    display: "resourceId",
    limit: 10,
    templates: {
      header: '<div class="mb-0 card-header"><h6 class="font-weight-bold mb-0">Resource ID</h6></div>',
      suggestion: function(data) {
        return `<p class="border-bottom-0 mb-0 list-group-item">${data.resourceId}</p>`
      }
    }
  })

  $('#findResource').bind({
    'typeahead:select': function(ev, suggestion) {
      const event = new CustomEvent('findResources', {
        detail: {
          evtType: 'findResource',
          searchableId: suggestion.searchableId
        }
      });
      window.dispatchEvent(event)
    }
  })
});

window.addEventListener('cyLoaded', function() {
  window.addEventListener('findResources', function(evt) {
    cy.nodes().unselect();
    const resource = cy.$(`[searchableId="${evt.detail.searchableId}"]`)
    const grandParent = resource.parent().parent()
    resource.select()
    cy.fit(grandParent, 50)

    var searchBarModalElem = document.getElementById('searchBarModal')
    var searchBarModal = coreui.Modal.getInstance(searchBarModalElem)

    searchBarModal.hide();
  })

  document.getElementById('showVpcs').addEventListener('change', function(event) {
    var visibility = event.target.checked;
    toggleVisibility('vpc', visibility)
    window.cy.nodes('[nodeType="region"]').map(function(node) { fixSingleChildParentWidth(node) })

    document.getElementById("showSubnets").disabled = !visibility;
    document.getElementById("showIGWs").disabled = !visibility;
    document.getElementById("showNGWs").disabled = !visibility;
    document.getElementById("showPeeringConnections").disabled = !visibility;
    window.layout.run();
  })

  document.getElementById('showSubnets').addEventListener('change',  function(event) {
    var visibility = event.target.checked;
    toggleVisibility('subnet', visibility)
    window.cy.nodes('[nodeType="vpc"]').map(function(node) { fixSingleChildParentWidth(node) })
    fixNodePadding('vpc')

    document.getElementById("showNGWs").disabled = !visibility;
    window.layout.run();
  })

  document.getElementById('showIGWs').addEventListener('change', function(event) {
    var visibility = event.target.checked;
    toggleVisibility('igw', visibility)
    window.cy.nodes('[nodeType="vpc"]').map(function(node) { fixSingleChildParentWidth(node) })
    fixNodePadding('vpc')
    window.layout.run();
  })

  document.getElementById('showNGWs').addEventListener('change', function(event) {
    var visibility = event.target.checked;
    toggleVisibility('ngw', visibility)

    fixNodePadding('subnet')
    window.layout.run();
  })

  document.getElementById('showTGWs').addEventListener('change', function(event) {
    var visibility = event.target.checked;
    toggleVisibility('tgw', visibility)
    window.cy.nodes('[nodeType="region"]').map(function(node) { fixSingleChildParentWidth(node) })

    document.getElementById("showTGWAttachments").disabled = !visibility;
    window.layout.run();
  })
})

// ---------------------------------------------
// Start Side Panel Resize
// ---------------------------------------------

export function infoPanelContainerFactory() {
  const resizer = document.createElement('div')
  resizer.classList.add('resizer', 'resizer-l')

  const infoPanel = document.createElement('div')
  infoPanel.classList.add('rounded-0',  'card')
  infoPanel.id = 'infoPanel';

  const infoPanelContainer = document.createElement('div')
  infoPanelContainer.id = 'infoPanelContainer'
  infoPanelContainer.appendChild(resizer)
  infoPanelContainer.appendChild(infoPanel)

  return infoPanelContainer
}

// The current position of mouse
let mouseX = 0;
let mouseY = 0;

// The dimension of the element
let eleW = 0;
let eleContainerW = 0;

let ele = null;
let eleContainer = null;

// Handle the mousedown event
// that's triggered when user drags the resizer
const resizeMouseDownHandler = function(e) {
    // Get the current mouse position
    mouseX = e.clientX;

    // Calculate the dimension of element
    const styles = window.getComputedStyle(ele);
    eleW = parseInt(styles.width, 10);
    eleContainerW = parseInt(styles.width, 10);

    // Attach the listeners to `document`
    document.addEventListener('mousemove', resizeMoveHandler);
    document.addEventListener('mouseup', resizeUpHandler);
};

const resizeMoveHandler = function(e) {
    // How far the mouse has been moved
    const dx = e.clientX - mouseX;

    // Adjust the dimension of element
    ele.style.width = `${eleW - dx}px`;
    eleContainer.style.width = `${eleContainerW - dx}px`;
};

const resizeUpHandler = function() {
    // Remove the handlers of `mousemove` and `mouseup`
    document.removeEventListener('mousemove', resizeMoveHandler);
    document.removeEventListener('mouseup', resizeUpHandler);
};

window.addEventListener('showInfoPanel', function() {
  ele = document.getElementById('infoPanel');
  eleContainer = document.getElementById('infoPanelContainer');

  const resizers = document.querySelectorAll('.resizer');
  [].forEach.call(resizers, function(resizer) {
    resizer.addEventListener('mousedown', resizeMouseDownHandler);  
  });

  const infoPanelResizers = document.querySelectorAll('.resizeInfoPanelIcon');
  [].forEach.call(infoPanelResizers, function(autoResizer) {
    autoResizer.addEventListener('click', function(e) {
      var target = e.target
      var newWidth = target.dataset.widthpercent;
      ele.style.width = newWidth;
      eleContainer.style.width = newWidth;
    })
  })
})

// ---------------------------------------------
// Start Share Email Behavior
// ---------------------------------------------

document.getElementById('shareEmailButton').onclick = function() {
  var options = {
    output: 'blob-promise',
    full: true,
    bg: 'white'
  }
  document.getElementById('shareEmailButton').innerHTML = '<span class="spinner-border spinner-border-sm">'
  var metaTags = Array.from(document.getElementsByTagName('meta'))
  var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content
  var email = document.getElementById('shareEmailInput').value;
  // TODO: A bazillion things can go wrong here. Fix this thing or add some kind of user feedback.
  cy.png(options).then((resp) => {
    var file = new File([resp], "temp");
    var data = {
      email: email,
      authenticity_token: csrfToken
    }
    axios.post("/get_upload_url", data)
    .then((resp) => {
      var url = resp.data.url;
      var fileName = resp.data.fileName
      axios.put(url, file)
        .then(() => {
          var data = {
            send_email_params: {
              email: email,
              fileName: fileName
            }
          }
          // TODO: Fix this spaghetti code
          axios.post("/send_share_email", data)
          .then((resp) => {
            document.getElementById('shareEmailButton').classList.remove('btn-primary')
            document.getElementById('shareEmailButton').classList.add('btn-success')
            document.getElementById('shareEmailButton').innerHTML = '<span><i class="mr-2 fa fa-check"></i>Shared</span>'

            setTimeout(() => {
              document.getElementById('shareEmailButton').innerHTML = '<span>Share</span>'
              document.getElementById('shareEmailButton').classList.remove('btn-success')
              document.getElementById('shareEmailButton').classList.add('btn-primary')
            }, 10000)
          })
        })
    })
  })
}

// ---------------------------------------------
// Start Overlays for Resources split across AZs
// ---------------------------------------------

function addAdditionalPaddingForOverlayParent() {
  var nodes = cy.nodes('[?isSpreadAcrossSubnets]')
  var azSpreadIds = nodes.map((n) => {
    return n.data().azSpreadId
  })

  let uniqueAzSpreadIds = [...new Set(azSpreadIds)]
  let spreadElementParentIds = []
  uniqueAzSpreadIds.forEach((azSpreadId, i) => {
    nodes = cy.nodes(`[azSpreadId='${azSpreadId}']`)
    spreadElementParentIds = spreadElementParentIds.concat(nodes.parent().map(function(p) {
      return p.data().id
    }))
  })

  let uniqueSpreadElementParentIds = [...new Set(spreadElementParentIds)]
  uniqueSpreadElementParentIds.forEach((parentId, i) => {
    var parentNode = cy.filter(`[id = "${parentId}"]`)[0]
    parentNode.style('padding', (parseInt(parentNode.style('padding').replace('px', '')) + 45) + 'px')
  })
}

function drawFakeParentNode(ctx, pos, childNodeType, label) {
  ctx.lineWidth = 2;

  var strokeStyleMappings = {
    'ecsService': {
      'border-color': '#d86613',
      'image': ecs_service_logo,
      'padding': 46
    },
    'eksNodegroup': {
      'border-color': '#d86613',
      'image': eks_cluster_logo,
      'padding': 46
    },
    'ec2Asg': {
      'border-color': '#d86613',
      'padding': 20
    }
  }

  ctx.strokeStyle = strokeStyleMappings[childNodeType]['border-color']
  var padding = strokeStyleMappings[childNodeType]['padding']

  if (strokeStyleMappings[childNodeType]['image'] !== undefined) {
    const image = new Image(48, 48);
    image.src = strokeStyleMappings[childNodeType]['image']
    ctx.drawImage(image, pos.x1-46, pos.y1-46, image.width, image.height)
  }
  ctx.strokeRect(pos.x1 - padding, pos.y1 - padding, pos.w + padding*2,pos.h + padding*2); // At node position
  ctx.font = window.getComputedStyle(document.getElementsByTagName('body')[0], null).font.replace(/\d+px/, "25px");;
}

function drawLabelForFakeParent(ctx, label, parentPos) {
  var string = fitString(ctx, label, parentPos.w)
  ctx.fillText(string, parentPos.x1 + 10, parentPos.y1 - 13)
}

function getLabelForFakeParent(childNode) {
  if (childNode.data().nodeType == 'ecsService') {
    return childNode.data().clusterName
  } else if (childNode.data().nodeType == 'eksNodegroup') {
    return childNode.data().clusterName
  } else if (childNode.data().nodeType == 'ec2Asg') {
    return ""
  }
}

const binarySearch = ({ max, getValue, match }) => {
  let min = 0;

  while (min <= max) {
    let guess = Math.floor((min + max) / 2);
    const compareVal = getValue(guess);

    if (compareVal === match) return guess;
    if (compareVal < match) min = guess + 1;
    else max = guess - 1;
  }

  return max;
};

const fitString = (
  ctx,
  str,
  maxWidth,
) => {
  let width = ctx.measureText(str).width;
  const ellipsis = '…';
  const ellipsisWidth = ctx.measureText(ellipsis).width;
  if (width <= maxWidth || width <= ellipsisWidth) {
    return str;
  }

  const index = binarySearch({
    max: str.length,
    getValue: guess => ctx.measureText(str.substring(0, guess)).width,
    match: maxWidth - ellipsisWidth,
  });

  return str.substring(0, index) + ellipsis;
};

function drawOverlaysForResourcesAcrossAzs() {
  var layer = cy.cyCanvas();
  var canvas = layer.getCanvas();
  var ctx = canvas.getContext('2d');

  cy.on("render cyCanvas.resize", function(evt) {
    layer.resetTransform(ctx);
    layer.clear(ctx);

    layer.setTransform(ctx);

    // Draw model elements
    var nodes = cy.nodes('[?isSpreadAcrossSubnets]')
    var azSpreadIds = nodes.map((n) => {
      return n.data().azSpreadId
    })

    let uniqueAzSpreadIds = [...new Set(azSpreadIds)]
    uniqueAzSpreadIds.forEach((azSpreadId, i) => {
      nodes = cy.nodes(`[azSpreadId='${azSpreadId}']`)
      var pos = nodes.boundingBox({
        includeLabels: false
      })

      if (nodes.length > 0) {
        var label = getLabelForFakeParent(nodes[0])
        drawFakeParentNode(ctx, pos, nodes[0].data().nodeType)
        drawLabelForFakeParent(ctx, label, pos)
      }
    })
  });
}

// ---------------------------------------------
// Start Export Diagram
// ---------------------------------------------

document.getElementById('exportVisualization').onclick = function() {
  if (cy.nodes().length == 0 && document.getElementById("emptyGraphAlert")) {
    document.getElementById("emptyGraphAlert").classList.remove('d-none')
    document.getElementById("emptyGraphAlert").classList.remove('d-block')
    return
  }
  var options = {
    output: 'blob-promise',
    full: true,
    bg: 'white'
  }
  cy.png(options).then((resp) => saveAs(resp, "architecture.png"))
}

// ---------------------------------------------
// Hover over Resource Behavior
// ---------------------------------------------

function highlightSubnetResourcePair(pairId) {
  if (pairId == undefined) {
    return
  }
  cy.nodes(`[pairHighlightId = '${pairId}']`).addClass('highlight-pair')
}

function removePairHighlighting(pairId) {
  if (pairId == undefined) {
    return
  }

  cy.nodes(`[pairHighlightId = '${pairId}']`).removeClass('highlight-pair')
}

window.addEventListener('cyLoaded', function(evt) {
  cy.on('mouseover', 'node', function(e){
    $('#vpcCanvas').css('cursor', 'pointer');
    const node = e.target
    const parent = e.target.parent()
    const grandParent = parent.parent()
    var hoverInfos = []
    const ancestors = [grandParent, parent, node]
    ancestors.forEach((n, i) => {
      if (n.data('hoverInfo')) {
        hoverInfos.push(n.data('hoverInfo'))
      }
    })

    const hoverText = hoverInfos.join(' - ')
    document.getElementById('hoverInfo').innerHTML = hoverText

    highlightSubnetResourcePair(node.data().pairHighlightId)
  });

  cy.on('mouseout', 'node', function(e){
      $('#vpcCanvas').css('cursor', 'default');
      const node = e.target
      document.getElementById('hoverInfo').innerHTML = ""

      removePairHighlighting(node.data().pairHighlightId)
  });
})

// ---------------------------------------------
// Bottom Right Controls Behavior
// ---------------------------------------------

document.getElementById('zoomIn').onclick = function() {
  cy.zoom(cy.zoom() + cy.zoom()*0.1)
}

document.getElementById('zoomOut').onclick = function() {
  cy.zoom(cy.zoom() - cy.zoom()*0.1)
}

document.getElementById('fitToScreen').onclick = function() {
  cy.fit([], 40)
}

// ---------------------------------------------
// Misc Layout Related
// ---------------------------------------------

window.addEventListener('cyLoaded', function(evt) {

  cy.on('remove', 'edge[edgeType = custom]', (evt) => {
    var edge = evt.target
    if (edge.data().mirrorEdgeId !== undefined) {
      var mirroredEdges = cy.edges(`[mirrorEdgeId = '${edge.data().mirrorEdgeId}']`)
      mirroredEdges.remove()
    }
  })

  cy.on('ehcomplete', (evt, src, tgt, edge) => {
    edge.data("edgeType", 'custom')
    if (tgt.data().isSpreadAcrossSubnets) {
      var mirrorNodes = cy.nodes(`[pairHighlightId = "${tgt.data().pairHighlightId}"]`)
      var mirrorEdgeId = uuidv4()
      edge.remove()
      mirrorNodes.forEach((node, i) => {
        cy.add({
          group: 'edges',
          data: {
            id: uuidv4(),
            source: src.id(),
            target: node.id(),
            edgeType: 'custom',
            mirrorEdgeId: mirrorEdgeId
          }
        })
      })
    }

    if (src.data().isSpreadAcrossSubnets) {
      edge.remove()
      var mirrorNodes = cy.nodes(`[pairHighlightId = "${src.data().pairHighlightId}"]`)
      var mirrorEdgeId = uuidv4()

      mirrorNodes.forEach((node, i) => {
        cy.add({
          group: 'edges',
          data: {
            id: uuidv4(),
            source: node.id(),
            target: tgt.id(),
            edgeType: 'custom',
            mirrorEdgeId: mirrorEdgeId
          }
        })
      })
    }
  })
})

window.addEventListener('cyLoaded', function(evt) {
  cy.on('layoutstop', function() {
    if (window.initialLayoutForFit && cy.nodes().length > 0) {
      cy.fit([], 40)
      window.initialLayoutForFit = false;
    }

    // Remove the spinner
    if (document.getElementById('loadingSpinner')) {
      document.getElementById('loadingSpinner').remove()
    }

    // Fixes this nasty bug - https://gitlab.com/vinay.nadig/quadzig/-/issues/40
    cy.nodes("[nodeType='region']").select();cy.nodes("[nodeType='region']").unselect();
  })

  if (!(evt.detail.displayConfig.nodes_layout === undefined)) {
    var cytoscapeNodes = evt.detail.displayConfig.nodes_layout
    layoutOptions = {
      name: 'preset',
      positions: (n) => {
        return {
          x: cytoscapeNodes.find((ne) => {
            return ne.id === n.id()
          }).position.x,
          y: cytoscapeNodes.find((ne) => {
            return ne.id == n.id()
          }).position.y
        }
      }
    }
  }

  axios.get("/views/infrastructure/aws_edges?exclude=securityGroup,tgwattch,peering", {
    params: {
      resource_group: new URLSearchParams(window.location.search).get("resource_group")
    }
  }).then((resp) => {
    var edges = resp.data
    edges.filter(e => e.data.edgeType === "custom").forEach((edge, i) => {
      if (
        (cy.filter(`[id = '${edge["data"]["source"]}']`).length !== 0) &&
        (cy.filter(`[id = '${edge["data"]["target"]}']`).length !== 0)
        ) {
        cy.add(edge)
      }
    })
  })

  cy.ready(() => {
    if (window.initialLayoutForLayout && cy.nodes().length > 0) {
      window.layout = cy.layout(layoutOptions);
      window.nodeEditingApi = cy.nodeEditing(nodeEditingOptions)
      window.expApi = cy.expandCollapse(expandCollapseOptions);
      window.gridGuide = cy.gridGuide(gridOptions);
      window.edgeHandlesApi = cy.edgehandles(edgeHandleOptions)
      window.cxtInstance = cy.contextMenus(cxtOptions)
      addAdditionalPaddingForOverlayParent()
      window.layout.run();
      window.initialLayoutForLayout = false

      drawOverlaysForResourcesAcrossAzs()
    }
  })
})

export function fixNodePadding(nodeType) {
  cy.nodes(`[nodeType="${nodeType}"]`)
    .filter((n) => {
      return n.children().length > 0
    }).map(n => n.style({'padding': '50px'}))

  cy.nodes(`[nodeType="${nodeType}"]`)
    .filter((n) => {
      return n.children().length === 0
    }).map(n => n.style({'padding': '0px'}))
}

export function fixSingleChildParentWidth(parent) {
  if (['region'].includes(parent.data('nodeType'))) {
    return undefined;
  }
  var children = parent.children()
  if (children.length == 1) {
    children.addClass('single-end-child')
  } else if (children.length > 1) {
    children.removeClass('single-end-child')
  }
}

window.initialLayoutForLayout = true;
window.initialLayoutForFit = true;
window.edgeHandlerStarted = false;
window.isDirty = false;

// ---------------------------------------------
// Extenstions Config
// ---------------------------------------------

var nodeEditingOptions = {
  zIndex: 1023,
  isNoControlsMode: function(n) {
    return n.is(":parent")
  },
  resizeToContentCueEnabled: function(n) {
    return false
  },
  isFixedAspectRatioResizeMode: function(n) {
    return false
  },
  padding: 0,
  grappleSize: 8,
  grappleColor: "lightgrey",
  boundingRectangleLineWidth: 1,
  boundingRectangleLineColor: "lightgrey",
  boundingRectangleLineDash: [0, 0],
}

export var layoutOptions = {
    name: 'fcose',
    quality: 'proof',
    avoidOverlap: true,
    nodeDimensionsIncludeLabels: true,
    animate: "end",
    randomize: false,
    fit: true,
    tile: true,
    tilingPaddingVertical: 24,
    tilingPaddingHorizontal: 24
  }

var edgeHandleOptions = {
  hoverDelay: 200,
  snap: true,
  snapFrequency: 5,
  noEdgeEventsInDraw: false
}

var gridOptions = {
  snapToGridOnRelease: true,
  drawGrid: false,
  gridSpacing: 24,
  resize: false,
  parentPadding: true,
  gridColor: 'black',
  parentSpacing: 50,
  gridStackOrder: 9999,
  snapToGridCenter: false,
  resize: false,
  guidelinesStyle: {
    strokeStyle: '#EBEDEF'
  }
}

// var nodeEditingOptions = {

// }

var expandCollapseOptions = {
  layoutBy: null,
  fisheye: true,
  animate: false,
  undoable: false,
  fit: true,
  cueEnabled: false
}

// ---------------------------------------------
// Right Click Resource Behavior
// ---------------------------------------------

function awsConsoleUrl(node) {
  const resourceId = node.data().id;
  const regionCode = node.data().regionCode;
  if (resourceId.startsWith("i-")) {
    return `https://console.aws.amazon.com/ec2/v2/home?region=${regionCode}#InstanceDetails:instanceId=${resourceId}`
  } else if (node.data().nodeType == 'rdsAuroraInstance') {
    return `https://console.aws.amazon.com/rds/home?region=${regionCode}#database:id=${resourceId};is-cluster=false`
  } else if (node.data().nodeType == 'rdsMysqlInstance') {
    return `https://console.aws.amazon.com/rds/home?region=${regionCode}#database:id=${resourceId};is-cluster=false`
  } else if (node.data().nodeType == 'rdsPostgresInstance') {
    return `https://console.aws.amazon.com/rds/home?region=${regionCode}#database:id=${resourceId};is-cluster=false`
  } else if (node.data().nodeType == 'awsLb') {
    return `https://console.aws.amazon.com/ec2/v2/home?region=${regionCode}#LoadBalancers:sort=loadBalancerName`
  } else if (node.data().nodeType == 'ecsCluster') {
    const clusterName = node.data().clusterName;
    return `https://${regionCode}.console.aws.amazon.com/ecs/home?region=${regionCode}#/clusters/${clusterName}/services`
  } else if (node.data().nodeType == 'ecsService') {
    const clusterName = node.data().clusterName;
    const serviceName = node.data().serviceName;
    return `https://${regionCode}.console.aws.amazon.com/ecs/home?region=${regionCode}#/clusters/${clusterName}/services/${serviceName}/details`
  } else if (resourceId.startsWith("vpc")) {
    return `https://console.aws.amazon.com/vpc/home?region=${regionCode}#VpcDetails:VpcId=${resourceId}`
  } else if (resourceId.startsWith("subnet")) {
    return `https://${regionCode}.console.aws.amazon.com/vpc/home?region=${regionCode}#SubnetDetails:subnetId=${resourceId}`
  } else if (resourceId.startsWith("nat")) {
    return `https://${regionCode}.console.aws.amazon.com/vpc/home?region=${regionCode}#NatGatewayDetails:natGatewayId=${resourceId}`
  } else if (resourceId.startsWith("igw")) {
    return `https://${regionCode}.console.aws.amazon.com/vpc/home?region=${regionCode}#InternetGateway:internetGatewayId=${resourceId}`
  } else if (resourceId.startsWith("tgw")) {
    return `https://${regionCode}.console.aws.amazon.com/vpc/home?region=${regionCode}#TransitGateways:transitGatewayId=${resourceId};sort=transitGatewayId`
  } else if (resourceId.startsWith("pcx")) {
    return `https://console.aws.amazon.com/vpc/home?region=${regionCode}#PeeringConnections:vpcPeeringConnectionId=${resourceId};sort=vpcPeeringConnectionId`
  } else if (node.data().nodeType == 'eksCluster') {
    const clusterName = node.data().clusterName
    return `https://console.aws.amazon.com/eks/home?region=${regionCode}#/clusters/${clusterName}`
  } else if (node.data().nodeType == 'eksNodegroup') {
    const nodegroupName = node.data().nodegroupName
    const clusterName = node.data().clusterName
    return `https://console.aws.amazon.com/eks/home?region=${regionCode}#/clusters/${clusterName}/nodegroups/${nodegroupName}`
  } else {
    return null;
  }
}

var cxtOptions = {
    evtType: 'cxttap', //Right click
    menuItems: [
      {
        id: 'openInAwsConsole',
        content: 'Open in AWS Console',
        hasTrailingDivider: true,
        selector: 'node',
        onClickFunction: function (event) {
          const url = awsConsoleUrl(event.target);
          if (url) {
            window.open(url)
          }
        },
        show: true
      },
      {
        id: 'drawConnection',
        content: 'Connect to another Resource',
        hasTrailingDivider: true,
        selector: 'node',
        onClickFunction: function (event) {
          edgeHandlerStarted = true
          window.edgeHandlesApi.start(event.target)
          isDirty = true
        },
        show: true
      },
      {
        id: 'editLabel',
        content: 'Edit Label',
        hasTrailingDivider: true,
        selector: 'node, edge',
        onClickFunction: function (event) {
          var element = event.target
          var modal = new coreui.Modal(document.getElementById('renameLabelModal'))
          var oldLabel = element.data().label || ""
          modal.show()

          document.getElementById('newLabelField').value = oldLabel
          document.querySelector('.modal#renameLabelModal button#saveLabelButton').onclick = (event) => {
            var newLabel = document.getElementById('newLabelField').value
            var metaTags = Array.from(document.getElementsByTagName('meta'))
            var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content

            console.log(element)
            if (element.isEdge()) {
              if ([undefined, 'custom'].includes(element.data().edgeType)) {
                if (element.data().mirrorEdgeId !== undefined) {
                  var mirroredEdges = cy.edges(`[mirrorEdgeId = '${element.data().mirrorEdgeId}']`)
                  mirroredEdges.data('label', newLabel)
                } else {
                  element.data('label', newLabel)
                }
                modal.hide()
                isDirty = true
                return
              }
            }

            var data = {
              nodeType: element.data().nodeType,
              resourceId: element.data().dbId,
              accountId: element.data().accountId,
              newLabel: newLabel,
              authenticity_token: csrfToken
            }
            axios.post("/infrastructure_view/update_view_configs", data)
            .then((resp) => {
              modal.hide()
              element.data('label', newLabel)
            })
          }
        },
        show: true
      },
      {
        id: 'addAnnotation',
        content: 'Add/Edit Annotation',
        hasTrailingDivider: true,
        selector: 'node, edge[edgeType != "custom"]',
        onClickFunction: function (event) {
          var element = event.target
          var modal = new coreui.Modal(document.getElementById('addAnnotationsModal'))
          var oldAnnotation = element.data().annotations || ""
          modal.show()

          document.getElementById('newAnnotationField').value = oldAnnotation
          document.querySelector('.modal#addAnnotationsModal button#saveAnnotationButton').onclick = (event) => {

            var annotations = document.getElementById('newAnnotationField').value
            var metaTags = Array.from(document.getElementsByTagName('meta'))
            var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content

            if (element.isEdge()) {
              if (element.data().edgeType == undefined) {
                element.data('annotations', annotations)
                modal.hide()
                return
              }
            }

            var data = {
              nodeType: element.data().nodeType,
              resourceId: element.data().dbId,
              accountId: element.data().accountId,
              annotations: annotations,
              authenticity_token: csrfToken
            }
            axios.post("/infrastructure_view/update_view_configs", data)
                .then((resp) => {
                  modal.hide()
                  element.data('annotations', annotations)
                })
            isDirty = true;
          }
        },
        show: true
      },
      {
        id: 'expandCollapse',
        content: 'Expand/Collapse Resource',
        hasTrailingDivider: true,
        selector: 'node',
        onClickFunction: function (event) {
          window.expApi.isCollapsible(event.target) ? window.expApi.collapse(event.target) : window.expApi.expand(event.target)
        },
        show: true
      },
      {
        id: 'Remove',
        content: 'Remove from Visualisation',
        tooltipText: 'Resource will be removed from visualisation. This will NOT remove the resource from your AWS Account.',
        selector: 'node, edge',
        hasTrailingDivider: true,
        onClickFunction: function (event) {
          // If this is the penultimate child,
          // make sure parent has minimum width
          // We can't use cy.on('remove') because
          // by then the parent information is already lost
          var parent = event.target.parent();
          event.target.remove()
          var children = parent.children()
          if (children.length == 1) {
            children.addClass('single-end-child')
          }
          fixNodePadding(parent.data('nodeType'))
          // window.layout.run();
          isDirty = true;
        },
        show: true
      }
    ],
    // css classes that menu items will have
    menuItemClasses: ['cxt-menu-item'],
    // css classes that context menu will have
    contextMenuClasses: ['cxt-menu']
    // Indicates that the menu item has a submenu. If not provided default one will be used
    // submenuIndicator: { src: 'assets/submenu-indicator-default.svg', width: 12, height: 12 }
};

// ----------------------------
// Resource Group Functionality
// ----------------------------

function saveCurrentResourceGroup(e) {
  var metaTags = Array.from(document.getElementsByTagName('meta'))
  var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content
  var jsonRep = window.cy.json()
  var nodes = jsonRep.elements.nodes

  nodes.forEach((n, i) => {
    var node = cy.filter(`[id = "${n['data']['id']}"]`)[0]
    if (!(node === undefined)) {
      var width = node.width()
      var height = node.height()
    }

    n["position"] = {
      x: node.position().x,
      y: node.position().y
    }

    n["dimensions"] = {
      w: width,
      h: height
    }
  })

  var data = {
    authenticity_token: csrfToken,
    config: {
      nodes: nodes,
      edges: jsonRep.elements.edges,
      resourceGroupId: new URLSearchParams(window.location.search).get("resource_group")
    }
  }

  axios.post("/save_current_resource_group", data)
  .then((resp) => {
    var toast = new coreui.Toast(document.getElementById('currentResourceGroupSaveSuccess'))
    toast.show();
    isDirty = false
  }).catch((e) => {
    var toast = new coreui.Toast(document.getElementById('currentResourceGroupSaveFailure'))
    toast.show();
  })
}

// Preset test
var saveRg1 = document.getElementById('saveCurrentResourceGroup1')
var saveRg2 = document.getElementById('saveCurrentResourceGroup2')
saveRg1 === null ? "" : saveRg1.addEventListener('click', saveCurrentResourceGroup)
saveRg2 === null ? "" : saveRg2.addEventListener('click', saveCurrentResourceGroup)

var resourceGroupItems = document.getElementsByClassName("resourceGroupSelection")

for(let i = 0; i < resourceGroupItems.length; i++) {
  resourceGroupItems[i].addEventListener("click", (e) => {
    window.location.search = `?resource_group=${e.target.dataset.rgId}`;
  })
}

document.getElementById("saveNewResourceGroupName").addEventListener("click", function(evt) {
  var rgName = document.getElementById("newResourceGroupName").value
  var metaTags = Array.from(document.getElementsByTagName('meta'))
  var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content
  var jsonRep = window.cy.json()
  var nodes = jsonRep.elements.nodes

  nodes.forEach((n, i) => {
    var node = cy.filter(`[id = "${n['data']['id']}"]`)[0]
    if (!(node === undefined)) {
      var width = node.width()
      var height = node.height()
    }

    n["position"] = {
      x: node.position().x,
      y: node.position().y
    }

    n["dimensions"] = {
      w: width,
      h: height
    }
  })

  var data = {
    authenticity_token: csrfToken,
    config: {
      nodes: nodes,
      edges: jsonRep.elements.edges,
      resourceGroupName: rgName
    }
  }
  axios.post("/save_as_new_resource_group", data)
  .then((resp) => {
    isDirty = false
    window.location.replace(`${window.location.pathname}?resource_group=${resp.data.rgId}`)
  }).catch((error) => {
    if (error.response.data.error_code !== 100) {
      var toast = new coreui.Toast(document.getElementById('currentResourceGroupSaveFailure'))
      toast.show();
    }
  })
})

window.addEventListener('cyLoaded', function() {
  cy.on('drag', 'node', function(evt) {
    isDirty = true
  })
})

function checkIfDirty() {
  if(isDirty){
    return "You have modified some content. Please save this form.";
  }
}

window.onbeforeunload = checkIfDirty;

// Utilities

function uuidv4() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}