#!/usr/bin/env bash
echo "cp"
hostnamectl set-hostname k8s-control
cat <<EOB >> /etc/hosts
172.31.10.100 k8s-control
172.31.10.101 k8s-worker1
172.31.10.102 k8s-worker2
EOB
