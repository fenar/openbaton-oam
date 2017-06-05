#!/bin/bash

#TMP_FOLDER=`mktemp -d`
#TRUSTY_IMAGE_NAME="Trusty-QCOW"
#XENIAL_IMAGE_NAME="Xenial-QCOW"
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

#echo "getting image id and tenant id for calling juju metadata generate-image"
#TRUSTY_IMAGE_ID=`openstack image show ${TRUSTY_IMAGE_NAME} -f value -c id`
#XENIAL_IMAGE_ID=`openstack image show ${XENIAL_IMAGE_NAME} -f value -c id`
#TENANT_ID=`openstack project show ${OS_TENANT_NAME} -f value -c id`
#juju metadata generate-image -d ${TMP_FOLDER} -i ${TRUSTY_IMAGE_ID} -s trusty -r ${OS_REGION_NAME} -u ${OS_AUTH_URL}
#juju metadata generate-image -d ${TMP_FOLDER} -i ${XENIAL_IMAGE_ID} -s xenial -r ${OS_REGION_NAME} -u ${OS_AUTH_URL}

#echo "creating containers on openstack swift"
#pushd ${TMP_FOLDER}
#swift upload simplestreams *

#swift post simplestreams --read-acl .r:*
#openstack service create --name product-stream --description "Product Simple Stream" product-streams
#popd

#SWIFT_INTERNAL_URL=`openstack endpoint show object-store -f value -c internalurl`
#SWIFT_PUBLIC_URL=`openstack endpoint show object-store -f value -c publicurl`
#ENDPOINT_PUBLIC_URL=$SWIFT_PUBLIC_URL/simplestreams/images
#ENDPOINT_INTERNAL_URL=$SWIFT_INTERNAL_URL/simplestreams/images

#echo creating endpoint create with publicurl ${ENDPOINT_PUBLIC_URL} and internalurl ${ENDPOINT_INTERNAL_URL}
#openstack endpoint create --region RegionOne --publicurl ${ENDPOINT_PUBLIC_URL} --internalurl ${ENDPOINT_INTERNAL_URL} product-streams
#juju bootstrap V4N-100 openstack-controller --debug --keep-broken --config image-metadata-url="$ENDPOINT_PUBLIC_URL"  --config network="$NETWORK_ID"  --config use-floating-ip=true --config use-default-secgroup=true --constraints instance-type=m1.large --bootstrap-series=trusty
juju bootstrap "${openstack_name}"  openstack-controller --debug --keep-broken --config availability-zone="kvm-zone" --config default-series="xenial" --config network="$NETWORK_ID"  --config use-floating-ip=true --config use-default-secgroup=true --constraints instance-type=m1.small
