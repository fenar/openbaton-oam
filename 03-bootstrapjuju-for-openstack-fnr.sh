#!/bin/bash
#Author fenar

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
NETWORK_NAME="private"

# gathering all information from openstack
NETWORK_ID=$(openstack network show "$NETWORK_NAME" --f value -c id)

juju bootstrap "${openstack_name}"  openstack-controller --debug --keep-broken --config availability-zone="kvm-zone" --config default-series="xenial" --config network="$NETWORK_ID"  --config use-floating-ip=true --config use-default-secgroup=true --constraints instance-type=m1.small
