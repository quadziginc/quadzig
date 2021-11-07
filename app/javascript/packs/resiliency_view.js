import './views_common'
import {
  toggleVisibility,
  toggleSingleNodeVisibility,
  toggleRegionVisibility,
  fixNodePadding,
  fixSingleChildParentWidth,
  layoutOptions,
  infoPanelContainerFactory
} from './views_common';
import axios from 'axios';
import mixPanelTrack from 'src/mixpanel_init';
import cytoscape from 'cytoscape';

// All logos used in application should also be imported here
// TODO: Find out why
import aws_cloud_logo from 'images/aws_icons/aws_cloud.png';
import igw_logo from 'images/aws_icons/igw.png';
import nat_gw_logo from 'images/aws_icons/nat_gw.png';
import private_subnet_logo from 'images/aws_icons/private_subnet.png';
import public_subnet_logo from 'images/aws_icons/public_subnet.png';
import region_logo from 'images/aws_icons/region.png';
import tgw_logo from 'images/aws_icons/tgw.png';
import vpc_logo from 'images/aws_icons/vpc.png';
import peering_conn_logo from 'images/aws_icons/peering_conn.png';
import general_logo from 'images/aws_icons/general.png';
import ec2_inst_a1_logo from 'images/aws_icons/ec2_inst_a1.png';
import ec2_inst_c4_logo from 'images/aws_icons/ec2_inst_c4.png';
import ec2_inst_c5_logo from 'images/aws_icons/ec2_inst_c5.png';
import ec2_inst_c5n_logo from 'images/aws_icons/ec2_inst_c5n.png';
import ec2_inst_d2_logo from 'images/aws_icons/ec2_inst_d2.png';
import ec2_inst_f1_logo from 'images/aws_icons/ec2_inst_f1.png';
import ec2_inst_g3_logo from 'images/aws_icons/ec2_inst_g3.png';
import ec2_inst_general_logo from 'images/aws_icons/ec2_inst_general.png';
import ec2_inst_h1_logo from 'images/aws_icons/ec2_inst_h1.png';
import ec2_inst_i3_logo from 'images/aws_icons/ec2_inst_i3.png';
import ec2_inst_m4_logo from 'images/aws_icons/ec2_inst_m4.png';
import ec2_inst_m5_logo from 'images/aws_icons/ec2_inst_m5.png';
import ec2_inst_m5a_logo from 'images/aws_icons/ec2_inst_m5a.png';
import ec2_inst_p2_logo from 'images/aws_icons/ec2_inst_p2.png';
import ec2_inst_p3_logo from 'images/aws_icons/ec2_inst_p3.png';
import ec2_inst_r4_logo from 'images/aws_icons/ec2_inst_r4.png';
import ec2_inst_r5_logo from 'images/aws_icons/ec2_inst_r5.png';
import ec2_inst_r5a_logo from 'images/aws_icons/ec2_inst_r5a.png';
import ec2_inst_t2_logo from 'images/aws_icons/ec2_inst_t2.png';
import ec2_inst_t3_logo from 'images/aws_icons/ec2_inst_t3.png';
import ec2_inst_t3a_logo from 'images/aws_icons/ec2_inst_t3a.png';
import ec2_inst_x1_logo from 'images/aws_icons/ec2_inst_x1.png';
import ec2_inst_x1e_logo from 'images/aws_icons/ec2_inst_x1e.png';
import ec2_inst_z1_logo from 'images/aws_icons/ec2_inst_z1.png';
import rds_postgres_instance_logo from 'images/aws_icons/rds_postgres_instance.png';
import rds_mysql_instance_logo from 'images/aws_icons/rds_mysql_instance.png';
import rds_aurora_instance_logo from 'images/aws_icons/rds_aurora_instance.png';
import alb_logo from 'images/aws_icons/alb.png';
import nlb_logo from 'images/aws_icons/nlb.png';
import asg_logo from 'images/aws_icons/asg.png';
import elb_logo from 'images/aws_icons/elb.png';
import ecs_service_service_logo from 'images/aws_icons/ecs_service_service.png';
import generic_ec2_group_logo from 'images/aws_icons/ec2_generic_group.png'
import elasticache_service_logo from 'images/aws_icons/elasticache_service.png';
import elasticache_redis_logo from 'images/aws_icons/elasticache_redis.png'
import elasticache_mem_logo from 'images/aws_icons/elasticache_mem.png'

function ec2BgImgMapping(instanceSize) {
  if (instanceSize.startsWith("a1")) { return ec2_inst_a1_logo }
  if (instanceSize.startsWith("c4")) { return ec2_inst_c4_logo }
  if (instanceSize.startsWith("c5")) { return ec2_inst_c5_logo }
  if (instanceSize.startsWith("5n")) { return ec2_inst_c5n_logo }
  if (instanceSize.startsWith("d2")) { return ec2_inst_d2_logo }
  if (instanceSize.startsWith("f1")) { return ec2_inst_f1_logo }
  if (instanceSize.startsWith("g3")) { return ec2_inst_g3_logo }
  if (instanceSize.startsWith("h1")) { return ec2_inst_h1_logo }
  if (instanceSize.startsWith("i3")) { return ec2_inst_i3_logo }
  if (instanceSize.startsWith("m4")) { return ec2_inst_m4_logo }
  if (instanceSize.startsWith("m5")) { return ec2_inst_m5_logo }
  if (instanceSize.startsWith("5a")) { return ec2_inst_m5a_logo }
  if (instanceSize.startsWith("p2")) { return ec2_inst_p2_logo }
  if (instanceSize.startsWith("p3")) { return ec2_inst_p3_logo }
  if (instanceSize.startsWith("r4")) { return ec2_inst_r4_logo }
  if (instanceSize.startsWith("r5")) { return ec2_inst_r5_logo }
  if (instanceSize.startsWith("5a")) { return ec2_inst_r5a_logo }
  if (instanceSize.startsWith("t2")) { return ec2_inst_t2_logo }
  if (instanceSize.startsWith("t3")) { return ec2_inst_t3_logo }
  if (instanceSize.startsWith("3a")) { return ec2_inst_t3a_logo }
  if (instanceSize.startsWith("x1")) { return ec2_inst_x1_logo }
  if (instanceSize.startsWith("1e")) { return ec2_inst_x1e_logo }
  if (instanceSize.startsWith("z1")) { return ec2_inst_z1_logo }
  return ec2_inst_general_logo
}

var style = [
  {
    selector: '.highlight-pair',
    style: {
      'overlay-color': 'red',
      'overlay-opacity': 0.1
    }
  },
  {
    selector: 'edge',
    style: {
      'curve-style': 'straight',
      'width': 2,
      'line-color': '#2364AA',
      'target-arrow-shape': 'triangle',
      'target-arrow-color': 'grey',
      'label': function(n) {
        if (n.data().label === undefined) {
          return ''
        } else {
          return n.data().label
        }
      }
    }
  },
  {
    // TODO: What's the best color?
    selector: 'node:selected',
    style: {
      'overlay-opacity': 0.1,
      'overlay-color': 'blue'
    }
  },
  {
    selector: '.aws-ec2-asg',
    style: {
      'background-opacity': 0,
      'shape': 'rectangle',
      'border-width': 2,
      'border-color': '#d86613',
      'background-image': function(e) { return `https://quadzig-production-visualization-assets.s3-us-west-1.amazonaws.com/asg/${e.data().desiredCapacity}.png` },
      'background-width': '120px',
      'background-height': '48px',
      'background-image-crossorigin': 'anonymous',
      'background-position-x': '0px',
      'background-position-y': '0px',
      'label': 'data(label)',
      'color': 'black',
      'text-halign': 'center',
      'text-valign': 'bottom',
      'width': '120px',
      'height': '48px',
      'min-zoomed-font-size': '16px',
      'text-wrap': function(node) {
        if (node.data().label.length > 25) {
          return 'ellipsis'
        } else {
          return 'wrap'
        }
      },
      'text-max-width': '120px',
      'text-margin-y': '4px'
    }
  },
  {
    selector: '.aws-eks-nodegroup',
    style: {
      'background-opacity': 0,
      'shape': 'rectangle',
      'border-width': 2,
      'border-color': '#d86613',
      'background-image': function(e) { return `https://quadzig-production-visualization-assets.s3-us-west-1.amazonaws.com/eks_nodegroup/${e.data().desiredCount}.png` },
      'background-width': '120px',
      'background-height': '48px',
      'background-image-crossorigin': 'anonymous',
      'background-position-x': '0px',
      'background-position-y': '0px',
      'label': 'data(label)',
      'color': 'black',
      'text-halign': 'center',
      'text-valign': 'bottom',
      'width': '120px',
      'height': '48px',
      'min-zoomed-font-size': '16px',
      'text-wrap': function(node) {
        if (node.data().label.length > 25) {
          return 'ellipsis'
        } else {
          return 'wrap'
        }
      },
      'text-max-width': '120px',
      'text-margin-y': '4px'
    }
  },
  {
    selector: '.aws-ec2-instance',
    style: {
      'shape': 'rectangle',
      'background-image': function(ele) { return ec2BgImgMapping(ele.data('instanceSize')) },
      'background-image-crossorigin': 'anonymous',
      'label': 'data(label)',
      'text-margin-y': '2px',
      'background-fit': 'contain',
      'text-valign': 'bottom',
      'text-halign': 'center',
      'width': '48px',
      'height': '48px',
      'background-opacity': 0,
      'min-zoomed-font-size': '16px',
      'text-max-width': '78px',
      'text-wrap': function(node) {
        if (node.data().label.length > 25) {
          return 'ellipsis'
        } else {
          return 'wrap'
        }
      }
    }
  },
  {
    selector: '.aws-rds-instance',
    style: {
      'shape': 'rectangle',
      'background-image-crossorigin': 'anonymous',
      'label': 'data(label)',
      'text-margin-y': '2px',
      'background-fit': 'contain',
      'text-valign': 'bottom',
      'text-halign': 'center',
      'width': '48px',
      'height': '48px',
      'text-wrap': function(node) {
        if (node.data().label.length > 25) {
          return 'ellipsis'
        } else {
          return 'wrap'
        }
      },
      'text-max-width': '78px',
      'background-opacity': 0,
      'min-zoomed-font-size': '16px'
    }
  },
  {
    selector: '.aws-db-instance',
    style: {
      'background-image': function(ele) { return (ele.data('nodeType') == 'rdsMysqlInstance' ? rds_mysql_instance_logo : rds_postgres_instance_logo) }
    }
  },
  {
    selector: '.aws-aurora-db-instance',
    style: {
      'background-image': rds_aurora_instance_logo
    }
  },
  {
    selector: '.aws-lb',
    style: {
      'shape': 'rectangle',
      'background-image-crossorigin': 'anonymous',
      'label': 'data(label)',
      'text-margin-y': '2px',
      'background-fit': 'contain',
      'text-valign': 'bottom',
      'text-halign': 'center',
      'text-wrap': function(node) {
        if (node.data().label.length > 25) {
          return 'ellipsis'
        } else {
          return 'wrap'
        }
      },
      'text-max-width': '78px',
      'width': '48px',
      'height': '48px',
      'background-opacity': 0,
      'min-zoomed-font-size': '16px'
    }
  },
  {
    selector: '.aws-application-lb',
    style: {
      'background-image': alb_logo
    }
  },
  {
    selector: '.aws-network-lb',
    style: {
      'background-image': nlb_logo
    }
  },
  {
    selector: '.aws-elb',
    style: {
      'shape': 'rectangle',
      'background-image-crossorigin': 'anonymous',
      'label': 'data(label)',
      'text-margin-y': '2px',
      'background-fit': 'contain',
      'text-valign': 'bottom',
      'text-halign': 'center',
      'text-wrap': function(node) {
        if (node.data().label.length > 25) {
          return 'ellipsis'
        } else {
          return 'wrap'
        }
      },
      'text-max-width': '78px',
      'width': '48px',
      'height': '48px',
      'background-opacity': 0,
      'min-zoomed-font-size': '16px',
      'background-image': elb_logo
    }
  },
  {
    selector: '.aws-ecs-service',
    style: {
      'shape': 'rectangle',
      'background-image': ecs_service_service_logo,
      'background-image-crossorigin': 'anonymous',
      'label': 'data(label)',
      'text-margin-y': '2px',
      'background-fit': 'contain',
      'text-valign': 'bottom',
      'text-halign': 'center',
      'width': '48px',
      'height': '48px',
      'background-opacity': 0,
      'min-zoomed-font-size': '16px',
      'text-max-width': '78px',
      'text-wrap': function(node) {
        if (node.data().label.length > 25) {
          return 'ellipsis'
        } else {
          return 'wrap'
        }
      }
    }
  },
  {
    selector: '.aws-account',
    style: {
      'background-opacity': 0,
      'shape': 'rectangle',
      'border-color': '#23303D',
      'border-width': 3,
      'background-image': aws_cloud_logo,
      'background-image-crossorigin': 'use-credentials',
      'background-width': '48px',
      'background-height': '48px',
      'background-position-x': '0px',
      'background-position-y': '0px',
      'padding': '60px',
      'label': 'data(label)',
      'font-size': '25px',
      'font-weight': 'bold',
      'color': '#23303E',
      'text-halign': 'center',
      'text-valign': 'top',
      'text-margin-x': '20px',
      'text-margin-y': '40px',
      'width': '192px',
      'text-wrap': 'wrap',
      'text-max-width': function(e) { return (e.outerWidth() + 'px') }
    }
  },
  {
    selector: '.aws-region',
    style: {
      'background-opacity': 0,
      'shape': 'rectangle',
      'border-color': '#167EBA',
      'border-width': 2,
      'background-image': region_logo,
      'background-image-crossorigin': 'use-credentials',
      'background-width': '48px',
      'background-height': '48px',
      'background-position-x': '0px',
      'background-position-y': '0px',
      'label': 'data(label)',
      'color': 'black',
      'font-size': '25px',
      'text-halign': 'center',
      'text-valign': 'top',
      'text-margin-x': '20px',
      'text-margin-y': '35px',
      'border-style': 'dashed',
      'width': '192px',
      'height': '48px',
      'text-wrap': 'wrap',
      'text-max-width': function(e) { return (e.outerWidth() + 'px') }
    }
  },
  {
    selector: '.aws-vpc',
    style: {
      'background-opacity': 0,
      'shape': 'rectangle',
      'border-color': '#248814',
      'border-width': 2,
      'background-image': vpc_logo,
      'background-image-crossorigin': 'use-credentials',
      'background-width': '48px',
      'background-height': '48px',
      'background-position-x': '0px',
      'background-position-y': '0px',
      'label': 'data(label)',
      'color': 'black',
      'text-valign': 'top',
      'font-size': '25px',
      'text-halign': 'center',
      'text-wrap': 'ellipsis',
      'text-margin-y': '38px',
      'text-margin-x': '15px',
      'text-max-width': function(n) {
        let width = n.outerWidth() - 85
        if (width < 0){
          return '144px'
        } else {
          return `${width}px`
        }
      },
      'width': '192px',
      'height': '48px',
      'min-zoomed-font-size': '16px'
    }
  },
  // {
  //   selector: '.aws-vpc:parent',
  //   style: {
  //     'font-size': '25px',
  //     'text-margin-x': function(ele) { return (ele.data('label').length * 2) + 'px' },
  //     'text-margin-y': '38px'
  //   }
  // },
  // {
  //   selector: '.aws-vpc:childless',
  //   style: {
  //     'font-size': '18px',
  //     'text-margin-x': function(ele) { return (ele.data('label').length * 2) + 'px' },
  //     'text-margin-y': '33px'
  //   }
  // },
  {
    selector: '.aws-ngw',
    style: {
      'shape': 'rectangle',
      'background-image': nat_gw_logo,
      'background-image-crossorigin': 'use-credentials',
      'label': 'data(label)',
      'text-margin-y': '2px',
      'background-fit': 'contain',
      'text-valign': 'bottom',
      'text-halign': 'center',
      'width': '48px',
      'height': '48px',
      'background-opacity': 0,
      'min-zoomed-font-size': '16px'
    }
  },
  {
    selector: '.aws-igw',
    style: {
      'shape': 'rectangle',
      'background-image': igw_logo,
      'background-image-crossorigin': 'use-credentials',
      'label': 'data(label)',
      'text-margin-y': '2px',
      'background-fit': 'contain',
      'text-valign': 'bottom',
      'text-halign': 'center',
      'text-wrap': function(node) {
        if (node.data().label.length > 25) {
          return 'ellipsis'
        } else {
          return 'wrap'
        }
      },
      'width': '48px',
      'height': '48px',
      'background-opacity': 0,
      'min-zoomed-font-size': '16px'
    }
  },
  {
    selector: '.aws-tgw',
    style: {
      'shape': 'rectangle',
      'background-image': tgw_logo,
      'background-image-crossorigin': 'use-credentials',
      'label': 'data(label)',
      'text-margin-y': '2px',
      'background-fit': 'contain',
      'text-valign': 'bottom',
      'text-halign': 'center',
      'width': '48px',
      'height': '48px',
      'background-opacity': 0,
      'min-zoomed-font-size': '16px'
    }
  },
  // This has to be at the end of the styling
  {
    selector: '.single-end-child',
    style: {
      'width': '125px'
    }
  },
  // TODO: Change to SVG
  {
    selector: '.aws-subnet',
    style: {
      'background-opacity': 0,
      'shape': 'rectangle',
      'border-width': 2,
      'background-image': public_subnet_logo,
      'background-image-crossorigin': 'use-credentials',
      'background-width': '48px',
      'background-height': '48px',
      'background-position-x': '0px',
      'background-position-y': '0px',
      'label': 'data(label)',
      'color': 'black',
      'text-halign': 'center',
      'text-valign': 'top',
      'text-margin-x': function(ele) { return (ele.data('label').length * 2) + 'px' },
      'text-margin-y': '38px',
      'width': '192px',
      'height': '48px',
      'min-zoomed-font-size': '16px',
      'text-wrap': 'wrap',
      'text-max-width': function(e) { return (e.outerWidth() + 'px') }
    }
  },
  {
    selector: '.aws-public-subnet',
    style: {
      'background-image': public_subnet_logo,
      'border-color': '#258814'
    }
  },
  {
    selector: '.aws-private-subnet',
    style: {
      'background-image': private_subnet_logo,
      'border-color': '#167eba'
    }
  },
  {
    selector: '.aws-subnet:parent',
    style: {
      'font-size': '25px',
      'text-margin-x': function(ele) { return (ele.data('label').length * 2) + 'px' },
      'text-margin-y': '38px'
    }
  },
  {
    selector: '.aws-subnet:childless',
    style: {
      'font-size': '18px',
      'text-margin-x': function(ele) { return (ele.data('label').length * 2) + 'px' },
      'text-margin-y': '33px'
    }
  },
  {
    selector: '.peering-conn',
    style: {
      'width': 2,
      'line-color': '#2364AA',
      'curve-style': 'unbundled-bezier',
      'target-arrow-shape': 'triangle',
      'target-arrow-color': 'grey',
      'source-arrow-shape': 'triangle',
      'source-arrow-color': 'grey'
    }
  },
  {
    selector: '.tgw-attch',
    style: {
      'width': 2,
      'line-color': '#F85A3E',
      'curve-style': 'unbundled-bezier',
      'target-arrow-shape': 'triangle',
      'target-arrow-color': 'grey',
      'source-arrow-shape': 'triangle',
      'source-arrow-color': 'grey'
    }
  },
  {
    selector: 'node:locked',
    style: {
      'overlay-opacity': 0.1,
      'overlay-color': 'black'
    }
  }
]

var removedPeeringConns = null;
var removedTGWAttchs = null;

axios.get("/views/resiliency/aws_nodes", {
  params: {
    resource_group: new URLSearchParams(window.location.search).get("resource_group")
  }
}).then((resp) => {
  try {
    var cytoscapeOptions = {
      container: document.getElementById('vpcCanvas'),
      style: style,
      elements: resp.data.elements,
      hideEdgesOnViewport: true,
      textureOnViewport: true,
      boxSelectionEnabled: false,
    }

    // if (!(resp.data.display_config.positions === undefined)) {
    //   cytoscapeOptions.layout = 'preset'
    // } 

    var cy = window.cy = cytoscape(cytoscapeOptions);

    const event = new CustomEvent('cyLoaded', {
      detail: {
        displayConfig: resp.data.display_config
      }
    });
    window.dispatchEvent(event)
  } catch (e) {
    window.location.reload();
  }

  window.resourceIdsForSearch = resp.data.elements.filter((ele) => {
    return ele["data"]["searchableName"] !== undefined
  }).map((ele) => {
    return {
      resourceId: ele["data"]["searchableName"],
      searchableId: ele["data"]["searchableId"]
    }
  })

  const event = new Event('searchIdsReady');
  window.dispatchEvent(event)

  cy.on('expandcollapse.afterexpand', function() {
    window.layout.run();
    // window.cy.reset()
  })

  cy.on('expandcollapse.afterexpand', 'node[nodeType="eksService"]', function(event) {
    event.target.style({ 'padding': '50px' })
  })

  cy.on('expandcollapse.aftercollapse', 'node[nodeType="eksService"]', function(event) {
    event.target.style({ 'padding': '0px' })
  })
  
  cy.on('expandcollapse.afterexpand', 'node[nodeType="eksCluster"]', function(event) {
    event.target.style({ 'padding': '50px' })
  })

  cy.on('expandcollapse.aftercollapse', 'node[nodeType="eksCluster"]', function(event) {
    event.target.style({ 'padding': '0px' })
  })
  
  cy.on('expandcollapse.afterexpand', 'node[nodeType="ec2Service"]', function(event) {
    event.target.style({ 'padding': '50px' })
  })

  cy.on('expandcollapse.aftercollapse', 'node[nodeType="ec2Service"]', function(event) {
    event.target.style({ 'padding': '0px' })
  })
  
  cy.on('expandcollapse.afterexpand', 'node[nodeType="rdsService"]', function(event) {
    event.target.style({ 'padding': '50px' })
  })

  cy.on('expandcollapse.aftercollapse', 'node[nodeType="rdsService"]', function(event) {
    event.target.style({ 'padding': '0px' })
  })
  
  cy.on('expandcollapse.afterexpand', 'node[nodeType="ecsServiceParent"]', function(event) {
    event.target.style({ 'padding': '50px' })
  })

  cy.on('expandcollapse.aftercollapse', 'node[nodeType="ecsServiceParent"]', function(event) {
    event.target.style({ 'padding': '0px' })
  })
  
  cy.on('expandcollapse.afterexpand', 'node[nodeType="ecsCluster"]', function(event) {
    event.target.style({ 'padding': '50px' })
  })

  cy.on('expandcollapse.aftercollapse', 'node[nodeType="ecsCluster"]', function(event) {
    event.target.style({ 'padding': '0px' })
  })

  document.getElementById('reOrganize').onclick = function() {
    // using existing window.layout object to re-run layout fucks up the layout.
    // always create a new one.
    window.cy.edges().remove();
    // document.getElementById("showPeeringConnections").checked = false;
    window.layout = cy.layout(layoutOptions);
    window.layout.run();
  }

  cy.on('select', 'node', function(event) {
    var nodeType = event.target.data().nodeType;
    if (
      (nodeType !== 'region') &&
      (nodeType !== 'igw') &&
      (nodeType !== 'vpc') &&
      (nodeType !== 'subnet') &&
      (nodeType !== 'tgw') &&
      (nodeType !== 'ngw')
      ) {
      
      let infoPanelContainer = infoPanelContainerFactory()
      var params = {}
      var id_field = 'dbId'
      params[id_field] = event.target.data().dbId
      params["account_id"] = event.target.data().accountId

      // Because we don't have direct association of ec2 instance with aws_account
      if (nodeType == "ec2instance") {
        params["vpc_id"] = event.target.data().vpcId
        params["subnet_id"] = event.target.data().subnetId
        params["ec2instance_id"] = event.target.data().instanceId
      }
      axios.get(`/views/resiliency/${nodeType}_info`, {
        params: params
      }).then((resp) => {
        let infoPanelContainer = infoPanelContainerFactory()
        document.getElementById('resiliency_view-index').append(infoPanelContainer)
        document.getElementById('infoPanel').innerHTML = resp.data;
        setTimeout(() => {
          const event = new Event('showInfoPanel');
          window.dispatchEvent(event)
        }, 1000)
      })
    }
  })

  cy.on('unselect', 'node', function(event) {
    if (cy.nodes(':selected').length === 0) {
      if (document.getElementById('infoPanelContainer')) {
        document.getElementById('infoPanelContainer').remove()
      }
    }
  })

  cy.ready(function(){
    let poppers = []
    var makeSevIssueDiv = function(element) {
      let colorCode = element.data().highSeverityIssuesCount == 0 ? 'warning' : 'danger'
      var div = document.createElement('div')
      div.innerHTML = `<i style="z-index: 1023;" class="text-${colorCode} fas fa-exclamation-triangle"></i>`
      document.body.appendChild(div)

      return div
    }

    function updatePopper() {
      poppers.forEach((p, i) => {
        p.update()
      })
    }
    
    let resourcesWithHighSevIssues = window.cy.nodes('[highSeverityIssuesCount != 0]')
    let resourcesWithMediumSevIssues = window.cy.nodes('[mediumSeverityIssuesCount != 0]')
    let resourcesWithIssues = resourcesWithHighSevIssues.union(resourcesWithMediumSevIssues)
    resourcesWithIssues.on('position', updatePopper)
    window.cy.on('pan zoom resize', updatePopper)

    resourcesWithIssues.forEach((element, i) => {
      let pop = element.popper({
        content: function() { return makeSevIssueDiv(element)},
        renderedDimensions: () => {
          return {w: element.renderedWidth(), h: element.renderedHeight()}
        },
        renderedPosition: () => {
          let offset = element.renderedOuterHeight()/2 * -1
          return { 
            // Compound nodes have a padding
            // (element.renderedOuterWidth() - element.renderedWidth())/2 gives us this padding value in terms of it's rendered size
            x: element.isParent() ? element.renderedPosition().x + (element.renderedOuterWidth() - element.renderedWidth())/2 : element.renderedPosition().x,
            y: element.renderedPosition().y + offset
          }
        },
        popper: {
          placement: 'top',
          modifiers: [
            {
              name: "constantWidth",
              enabled: true,
              fn: ({ state }) => {
                state.styles.popper.width = `${element.renderedHeight() * 0.3}px` ;
                state.styles.popper.height = `${element.renderedHeight() * 0.3}px` ;
                state.styles.popper.fontSize = `${element.renderedHeight() * 0.3}px` ;
              },
              phase: "beforeWrite",
              requires: ["computeStyles"],
            }
          ]
        }
      })
      poppers.push(pop)
    })
  })

  document.getElementById('syncResources').onclick = function() {
    mixPanelTrack("infra_sync_triggered", {"source": "resiliency_view_page"})

    var metaTags = Array.from(document.getElementsByTagName('meta'))
    var csrfToken = metaTags.filter(e => e.name === "csrf-token")[0].content
    axios.post("/views/resiliency/refresh_infra", {
      authenticity_token: csrfToken
    }).then(resp => {
      window.location.reload();
    })
  }
})

window.onload = function() {
  mixPanelTrack("visited_resiliency_view", {})
}
