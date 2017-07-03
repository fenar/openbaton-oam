#!/bin/bash -eu
# Trigger a service restart
#
openstack_service_list=(openstack-dashboard keystone glance cinder neutron-api nova-cloud-controller neutron-gateway)

get_units ()
{
cat << EOF| python -
import json, subprocess, re
from subprocess import check_output

data = subprocess.check_output(['juju', 'status', '--format=json'])
j = json.loads(data)
services = j['applications']
print '\n'.join(services["$1"]['units'].keys())
EOF
}

for service in ${openstack_service_list[@]}
do
    for unit in `get_units $service`
    do
        juju ssh $unit "sudo reboot now"
        echo -e "INFO-LOG:$(date): Reboot-ing $unit"
    done
done
