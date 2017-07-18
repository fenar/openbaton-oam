#!/bin/bash
# Author: Fatih E. Nar (fenar)
# Destroy Openstack Model + JUJUGVNFM Jump Host
#
set -ex
model=`juju list-models |awk '{print $1}'|grep openstack`
obnum=`hostname | cut -c 10- -`
#NODE="node10ob$obnum"
if [[ ${model:0:9} == "openstack" ]]; then
     echo "Model:Openstack Found -> Destroy in Progress!"
     juju destroy-model "openstack" -y
#     NODE_ID=$(maas admin nodes read hostname=$NODE | python -c "import sys, json;print json.load(sys.stdin)[0]['system_id']")
#     maas admin machine release "$NODE_ID"
else
     echo "Model:Openstack NOT Found!"
fi
