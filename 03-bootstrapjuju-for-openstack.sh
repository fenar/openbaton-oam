#!/usr/bin/env bash
#
# juju 2.1.2
# maas 2.1.5
# openstack ocata

unalias -a
obnum=`hostname | cut -c 10- -`
trap 'echo "Error at about $LINENO"' ERR

set -o errexit
set -o pipefail
set -o nounset

readonly openstack_name="openstack-OB$obnum"
echo "Adding new OpenStack cloud named '$openstack_name'"

[ -r nova.rc ] || { echo "nove.rc unreadable. Exiting."; exit 1; } 

source nova.rc

cat <<EOF > juju-openstack-cloud.yaml
clouds:
    ${openstack_name}:
      type: openstack
      auth-types: [access-key, userpass]
      regions:
        ${OS_REGION_NAME}:
          endpoint: "${OS_AUTH_URL}"
EOF

# XXX handle the case where $openstack_name already exists
juju add-cloud "$openstack_name" juju-openstack-cloud.yaml --replace

cat <<EOF > juju-openstack-cred.yaml
credentials:
      ${openstack_name}:
        default-region: "${OS_REGION_NAME}"
        "$OS_USERNAME":
          auth-type: userpass
          password: "$OS_PASSWORD"
          tenant-name: "$OS_TENANT_NAME"
          username: "$OS_USERNAME"
EOF

juju add-credential "${openstack_name}" --replace -f juju-openstack-cred.yaml

#gss_status="$(juju status glance-simplestreams-sync)" 

#echo "$gss_status" | grep -q ^glance-simplestreams-sync
#[ $? -eq 0 ] || { echo "Charm glance-simplestreams-sync is not already installed. Existing"; exit 1; } 

#echo "$gss_status" | grep -q "Sync completed at"
#[ $? -eq 0 ] || { echo "Charm glance-simplestreams-sync has not synced the cloud images yet. Existing"; exit 1; } 

readonly private_network_name="private"
private_network_id="$(openstack network list | fgrep "$private_network_name" | awk '{print $2}')"

juju bootstrap "${openstack_name}" --show-log --debug \
	--config network="$private_network_id" \
	--config default-series="xenial" --config use-floating-ip=true

juju model-defaults use-floating-ip=true network="$private_network_name"
