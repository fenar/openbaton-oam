#!/bin/bash
#
# OpenBaton Deployment Kick-Starter
# Author:Fatih E. Nar (fenar)
#
model=`juju list-models |awk '{print $1}'|grep openstack`

if [ ! -d openbaton-charm ]; then
  echo "creating openbaton-charm"
  git clone https://github.com/fenar/juju-charm.git openbaton-charm
  sleep 10s
fi

echo "Available Openstack Deployment Options:"
echo "(1) -> Openstack Newton with OVS"
echo "(2) -> Openstack Ocata with Calico"
echo "Enter Your Choice: "
read -n 2 r
if [ "$r" = "1" ] ; then
        echo "Deploying Openstack Newton with OVS"
        if [[ ${model:0:9} == "openstack" ]]; then
                juju switch openstack
                juju deploy openstack-newton-openbaton.yaml
        else
                juju add-model openstack
        	juju switch openstack
        	juju deploy openstack-newton-openbaton.yaml
        fi
elif [ "$r" = "2" ] ; then
        echo "Deploying Openstack Ocata with Calico"
        if [ ! -d charm-neutron-api ]; then
        	git clone -b ocata-support https://github.com/projectcalico/charm-neutron-api.git
        fi
	if [[ ${model:0:9} == "openstack" ]]; then
	  	juju switch openstack
     		juju deploy calico-ocata.yaml
	else
		juju add-model openstack
		juju switch openstack
     		juju deploy calico-ocata.yaml
	fi
else
        echo "Incorrect Release Selection!"
        exit
fi
echo "Login to the juju-gui to see status or use juju status"
juju gui --no-browser --show-credentials

