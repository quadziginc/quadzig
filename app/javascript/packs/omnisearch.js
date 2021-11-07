import clipboard from 'clipboard';
new clipboard('.copy-btn');
import axios from 'axios';
import mixPanelTrack from 'src/mixpanel_init';

import general_logo from 'images/aws_icons/general.png';
import ecs_service_logo from 'images/aws_icons/ecs_service.png';
import vpc_logo from 'images/aws_icons/vpc.png';
import tgw_logo from 'images/aws_icons/tgw.png';
import public_subnet_logo from 'images/aws_icons/public_subnet.png';
import nat_gw_logo from 'images/aws_icons/nat_gw.png';
import alb_logo from 'images/aws_icons/alb.png';
import igw_logo from 'images/aws_icons/igw.png';
import ecs_service_service_logo from 'images/aws_icons/ecs_service_service.png';
import ec2_inst_general_logo from 'images/aws_icons/ec2_inst_general.png';
import rds_general_logo from 'images/aws_icons/rds_general.png';
import peering_conn_logo from 'images/aws_icons/peering_conn.png';
import rds_aurora_general_logo from 'images/aws_icons/rds_aurora_general.png';

var syncButton = document.getElementById('syncResources')
syncButton.onclick = function() {
  mixPanelTrack("infra_sync_triggered", {
    "source": "omnisearch_page"
  })

  var metaTags = Array.from(document.getElementsByTagName('meta'))
  var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content
  syncButton.innerHTML = '<div class="d-flex justify-content-center"><div class="spinner-border-sm spinner-border" role="status"><span class="sr-only">Loading...</span></div></div>'
  axios.post("/views/network/refresh_infra", {
    authenticity_token: csrfToken
  }).catch(e => {
    syncButton.innerHTML = "Error!"
  })

  setTimeout(() => {
    syncButton.innerHTML = "Sync Resources"
  }, 3000)
}

window.onload = function() {
  mixPanelTrack("visited_omnisearch_page", {})
}

var omnisearchForm = document.getElementById("omnisearchForm")
omnisearchForm.onsubmit = (event) => {
  const query = document.getElementById("search_string").value
  mixPanelTrack("omnisearch", {
    "query": query
  })
}