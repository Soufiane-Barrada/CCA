#!/bin/bash 
set -e
STATE_STORE="gs://cca-eth-2025-group-0031-cmichel/"


export KOPS_STATE_STORE=$STATE_STORE
export PROJECT=`gcloud config get-value project`

kops create -f part4.yaml
kops update cluster --name part4.k8s.local --yes --admin
kops validate cluster --wait 10m

