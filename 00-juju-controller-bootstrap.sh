#!/bin/bash
#

set -eaux

obnum=`hostname | cut -c 10- -`

time juju bootstrap --config bootstrap-timeout=1200 --to node00vm1ob${obnum}.maas --show-log v4n${obnum}-maas  maas-v4n${obnum}-controller

juju gui --no-browser --show-credentials
