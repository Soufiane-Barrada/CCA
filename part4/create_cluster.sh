#!/bin/bash 

CLUSTER_NAME="part4.k8s.local"
STATE_STORE="gs://cca-eth-2025-group-031-mpinto/"
ZONE="europe-west1-b"
export PROJECT=$(gcloud config get-value project)
export KOPS_STATE_STORE=$STATE_STORE

kops create -f part4.yaml
kops update cluster --name $CLUSTER_NAME --yes --admin 
kops validate cluster --wait 10m
sleep 10

echo "[Matteo Log] cluster up!"
kubectl get nodes -o wide 

