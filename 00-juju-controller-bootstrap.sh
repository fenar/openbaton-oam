#!/bin/bash
#

set -eaux

obnum=`hostname | cut -c 10- -`

time juju bootstrap --config bootstrap-timeout=1200 --to node00vm0ob${obnum}.maas --show-log maas maas/172.27.${obnum}.1

juju gui --no-browser --show-credentials
