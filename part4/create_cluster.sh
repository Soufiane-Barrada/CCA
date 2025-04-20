#!/bin/bash 
set -e


CLUSTER_NAME="part4.k8s.local"
STATE_STORE="gs://cca-eth-2025-group-031-cmichel/"
ZONE="europe-west1-b"
 
export KOPS_STATE_STORE=$STATE_STORE
export PROJECT=`gcloud config get-value project`
 
kops create -f part4.yaml
kops update cluster --name $CLUSTER_NAME --yes --admin 
kops validate cluster --wait 10m
 
echo "[Matteo Log] cluster up!"
#kubectl get nodes -o wide 

