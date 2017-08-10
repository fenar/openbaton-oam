#!/bin/bash
# Trigger a sctp kernel module loading on nova-hosts
# Fatih E. NAR
nova_list=(nova-compute)
for host in ${nova_list[@]}
do
  for instance in {1..5}
  do 
    juju ssh $host/$instance "sudo modprobe nf_conntrack_proto_sctp"
    juju ssh $host/$instance "sudo modprobe nf_nat_proto_sctp"
  done
done
