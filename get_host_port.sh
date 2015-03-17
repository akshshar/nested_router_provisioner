#!/bin/bash
host_port=`ps -ef | grep $1 | grep kvm | awk '{print $59}'`


split_var=(${host_port//:/ })
split_var_port=${split_var[2]}
split_host_final=(${split_var_port//,/ })

echo ${split_host_final[0]}
