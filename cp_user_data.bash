#!/usr/bin/env bash

set -e

# Set hostname
hostnamectl set-hostname k8s-control

# Setup hosts file
cat <<EOB >> /etc/hosts
172.31.10.100 k8s-control
172.31.10.101 k8s-worker1
172.31.10.102 k8s-worker2
EOB

# Load kernel modules
cat << EOB > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOB
modprobe overlay
modprobe br_netfilter

# Sysctl setup
cat <<EOB > /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOB
sysctl --system

# Install containerd
apt update
apt install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl restart containerd

# Turn off swap
swapoff -a

# Install Kubernetes components
apt install -y apt-transport-https curl
#curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.27/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.27/deb/ /
EOF
#cat << EOB > /etc/apt/sources.list.d/kubernetes.list
#deb https://apt.kubernetes.io/ kubernetes-xenial main
#EOB
apt update
#apt install -y kubelet=1.23.0-00 kubeadm=1.23.0-00 kubectl=1.23.0-00
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# Start cluster
kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.27.11

# Setup kube config for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

# Install networking
#sudo -i -u ubuntu kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
sudo -i -u ubuntu kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml

# Generate a kubeadm bootstrap token
kubeadm token create nikola.bootstraptoken01


echo y > /root/y
