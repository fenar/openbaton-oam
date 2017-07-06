#!/bin/bash
# Trigger a service restart
#
openstack_service_list=(openstack-dashboard keystone glance cinder neutron-api nova-cloud-controller neutron-gateway openbaton)

for service in ${openstack_service_list[@]}
do
  juju ssh $service/0 "sudo reboot now"
done
