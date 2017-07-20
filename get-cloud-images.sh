#!/bin/bash -e

folder=/srv/data
URLS="http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img \
http://mirror.catn.com/pub/catn/images/qcow2/centos6.4-x86_64-gold-master.img \
http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img "

for URL in $URLS
do
FILENAME=${URL##*/}
if [ -f $folder/$FILENAME ];
then
    echo "$FILENAME already downloaded." 
else
    wget -q -O  $folder/$FILENAME $URL
fi
done
