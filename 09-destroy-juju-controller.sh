#!/bin/bash
#
# Fatih E. NAR (fenar)
set -eaux

obnum=`hostname | cut -c 10- -`

juju kill-controller maas/172.27.${obnum}.1
