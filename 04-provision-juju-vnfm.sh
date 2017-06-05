#!/bin/bash
# Copyright (c) 2017 Open Baton Project. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# requirements: python-openstackclient and python-swiftclient installed
# you need to update image name with the one you have in 02-provision-openstack.sh
# it assumes nova.rc file already exists (RegionOne is used as default region)
# it creates a container on swift later on used by juju for retrieving metadata info
#
# Authors:
#         Giuseppe Carella (gc4rella)
#         Fatih E. Nar (fenar)
#
set -ex

# source nova.rc file for gathering info from openstack
source nova.rc

TMP_FOLDER=`mktemp -d`
TRUSTY_IMAGE_NAME="Trusty-QCOW"
XENIAL_IMAGE_NAME="Xenial-QCOW"
NETWORK_NAME="private"
obnum=`hostname | cut -c 10- -`
NODE="node10ob$obnum"

# NEW VARS
OPENSTACK_FILE=openstack-config.yaml
CREDENTIALS_FILE=gvnfm-credentials.yaml
USERDATA_FILE=gvnfm-userdata.sh

# gathering all information from openstack
NETWORK_ID=$(openstack network show "$NETWORK_NAME" --f value -c id)

echo "getting image id and tenant id for calling juju metadata generate-image"
TRUSTY_IMAGE_ID=`openstack image show ${TRUSTY_IMAGE_NAME} -f value -c id`
XENIAL_IMAGE_ID=`openstack image show ${XENIAL_IMAGE_NAME} -f value -c id`
TENANT_ID=`openstack project show ${OS_TENANT_NAME} -f value -c id`
juju metadata generate-image -d ${TMP_FOLDER} -i ${TRUSTY_IMAGE_ID} -s trusty -r ${OS_REGION_NAME} -u ${OS_AUTH_URL}
juju metadata generate-image -d ${TMP_FOLDER} -i ${XENIAL_IMAGE_ID} -s xenial -r ${OS_REGION_NAME} -u ${OS_AUTH_URL}

echo "creating containers on openstack swift"
pushd ${TMP_FOLDER}
swift upload simplestreams *
swift post simplestreams --read-acl .r:*
openstack service create --name product-stream --description "Product Simple Stream" product-streams
popd

SWIFT_INTERNAL_URL=`openstack endpoint show object-store -f value -c internalurl`
SWIFT_PUBLIC_URL=`openstack endpoint show object-store -f value -c publicurl`
ENDPOINT_PUBLIC_URL=$SWIFT_PUBLIC_URL/simplestreams/images
ENDPOINT_INTERNAL_URL=$SWIFT_INTERNAL_URL/simplestreams/images

echo creating endpoint create with publicurl ${ENDPOINT_PUBLIC_URL} and internalurl ${ENDPOINT_INTERNAL_URL}
openstack endpoint create --region RegionOne --publicurl ${ENDPOINT_PUBLIC_URL} --internalurl ${ENDPOINT_INTERNAL_URL} product-streams

# deploy node on maas
maas admin machines allocate name=$NODE
# NODE_ID=$(maas admin nodes read hostname=$NODE | grep system_id | cut -d'"' -f4 | sed -n 2p)
NODE_ID=$(maas admin nodes read hostname=$NODE | python -c "import sys, json;print json.load(sys.stdin)[0]['system_id']")
maas admin machine deploy "$NODE_ID"

# wait till the machine is up
while [ "$(maas admin nodes read hostname=$NODE | python -c "import sys, json;print json.load(sys.stdin)[0]['status_name']")" != "Deployed" ]
do
    echo "Waiting for ready on $NODE..."
    sleep 10s
done

# check if ssh is up
while ! ssh $NODE.maas echo
do
    echo "Waiting for sshd on $NODE..."
    sleep 10s
done

# copy over the used ssh-keypair
scp ~/.ssh/id_rsa ~/.ssh/id_rsa.pub $OPENSTACK_FILE $CREDENTIALS_FILE $NODE.maas:.ssh/

# prepare the config files for private cloud
sed -i.bak "s#%endpoint%#$OS_AUTH_URL#;" "${OPENSTACK_FILE}"
sed -i.bak "s/%password%/$OS_PASSWORD/; s/%tenant-name%/$OS_TENANT_NAME/; s/%username%/$OS_USERNAME/;" "${CREDENTIALS_FILE}"
# bring the config files to the machine
scp $OPENSTACK_FILE $CREDENTIALS_FILE $NODE.maas:./

# install and bootstrap juju
bootstrap_juju() {
    set -ex
    export DEBIAN_FRONTEND=noninteractive


    while [ ! -z "$(sudo lsof /var/lib/dpkg/lock)" ]
    do
        echo "Waiting for apt lock..."
        sleep 5s
    done

    sudo -E add-apt-repository -y ppa:juju/devel
    sleep 10s
    sudo apt-get update
    sleep 45s
    sudo -E apt-get install -y --allow-unauthenticated juju python3-pip
    sleep 10s
    juju add-cloud openstack $OPENSTACK_FILE
    juju add-credential openstack -f $CREDENTIALS_FILE
    juju bootstrap openstack obcontroller --debug --keep-broken --config image-metadata-url="$ENDPOINT_PUBLIC_URL"  --config network="$NETWORK_ID"  --config use-floating-ip=true --config use-default-secgroup=true --constraints instance-type=m1.large --bootstrap-series=trusty
}
typeset -f | ssh $NODE.maas "export OPENSTACK_FILE=$OPENSTACK_FILE;CREDENTIALS_FILE=$CREDENTIALS_FILE;export NETWORK_ID=$NETWORK_ID;export ENDPOINT_PUBLIC_URL=$ENDPOINT_PUBLIC_URL; $(cat);bootstrap_juju"

# bring the config file to the machine
scp $USERDATA_FILE $NODE.maas:./

start_vnfm() {
    pip3 install --user juju-vnfm
    sudo mkdir -p /etc/openbaton/juju
    sudo mkdir -p /var/log/openbaton
    sudo cp $USERDATA_FILE /etc/openbaton/juju/userdata.sh
    sudo chown -R ubuntu:ubuntu /var/log/openbaton
    sudo chown -R ubuntu:ubuntu /etc/openbaton/juju

    screen -dmS jujuvnfm
    screen -S jujuvnfm -p 0 -X stuff "bash$(printf \\r)"
    screen -S jujuvnfm -p 0 -X stuff "PATH=$(echo $PATH:/home/ubuntu/.local/bin)$(printf \\r)"
    screen -S jujuvnfm -p 0 -X stuff "jujuvnfm -d -t 10 start$(printf \\r)"
}
OPENBATON_IP=$(juju run --application openbaton 'unit-get public-address')
typeset -f | ssh $NODE.maas "export JUJU_VNFM_CHARM_STATUS_TIMEOUT=6000;export JUJU_VNFM_BROKER_IP=$OPENBATON_IP; export USERDATA_FILE=$USERDATA_FILE; $(cat);start_vnfm"

# restore the default files
mv "$OPENSTACK_FILE.bak" "$OPENSTACK_FILE"
mv "$CREDENTIALS_FILE.bak" "$CREDENTIALS_FILE"
