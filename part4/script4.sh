#!/bin/bash

set -e 

# -- config --

CLUSTER_NAME="part4.k8s.local"
STATE_STORE="gs://cca-eth-2025-group-031-mpinto/"
ZONE="europe-west1-b"
CONTROLLER_SCRIPT="controller.py"
LOGGER_SCRIPT="scheduler_logger.py"

# -- end config  -- 

# -- create the cluster --  
echo "[Matteo Log] creating cluster" 

export KOPS_STATE_STORE=$STATE_STORE
PROJECT=$(gcloud config get-value project)
kops create -f part4.yaml 
kops update cluster --name $CLUSTER_NAME --yes --admin
kops validate cluster --wait 10m
echo "[Matteo Log] cluster up, resting for 10s"
sleep 10

# -- cluster created -- 

# -- getting IPs and VM names --
echo "[Matteo Log] getting IPs and VM names"
kubectl get nodes -o wide > cluster_nodes_infos.txt

MEMCACHED_VM=$(grep '^memcache-server' cluster_nodes_infos.txt | awk '{print $1}')
MEMCACHED_IP=$(grep '^memcache-server' cluster_nodes_infos.txt | awk '{print $6}')
CLIENT_AGENT_VM=$(grep '^client-agent' cluster_nodes_infos.txt | awk '{print $1}')
CLIENT_AGENT_IP=$(grep '^client-agent' cluster_nodes_infos.txt | awk '{print$6}')
CLIENT_MEASURE_VM=$(grep '^client-measure' cluster_nodes_infos.txt | awk '{print $1}')
CLIENT_MEASURE_IP=$(grep '^client-measure' cluster_nodes_infos.txt | awk '{print $6}')
echo "[Matteo Log] Memcached internal IP is: $MEMCACHED_IP"
echo "[Matteo Log] Memcached VM name is: $MEMCACHED_VM"
echo "[Matteo Log] client agent internal IP is: $CLIENT_AGENT_IP"
echo "[Matteo Log] client agent VM name is: $CLIENT_AGENT_VM"
echo "[Matteo Log] client measure intenral IP is: $CLIENT_MEASURE_IP"
echo "[Matteo Log] client measure VM name is: $CLIENT_MEASURE_VM"

# -- IPs and VM names retrieved 


# -- setting up memcache-server VM -- 

echo "[Matteo Log] setting up memcached on $MEMCACHED_VM"

gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
  sudo apt update &&
  sudo apt install -y memcached libmemcached-tools &&
  sudo sed -i 's/-m .*/-m 1024/' /etc/memcached.conf &&
  sudo sed -i 's/-l .*/-l ${MEMCACHED_IP}/' /etc/memcached.conf &&
  sudo sed -i '/^-t /d' /etc/memcached.conf &&
  echo '-t 2' | sudo tee -a /etc/memcached.conf &&
  sudo systemctl restart memcached &&
  echo '[Matteo Log] Memcached installed and configured!'
"
# -- memcache-server VM set up -- 


MCPERF_SCRIPT="sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources &&
  sudo apt-get update && 
  sudo apt-get install libevent-dev libzmq3-dev git make g++ --yes && 
  sudo apt-get build-dep memcached --yes && 
  git clone https://github.com/eth-easl/memcache-perf-dynamic.git && 
  cd memcache-perf-dynamic && 
  make && 
  echo '[Matteo Log] mcperf augmented installed and configured!'"


# -- setting up client-agent and client-measure VM

echo "[Matteo Log] setting up $CLIENT_AGENT_VM"
gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "$MCPERF_SCRIPT"
echo "[Matteo Log] setting up $CLIENT_MEASURE_VM"
gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "$MCPERF_SCRIPT"

# -- client-agent and client-measure VM set up 

# -- launching mcperf memcached client load -- 
gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "cd memcache-perf-dynamic && ./mcperf -T 8 -A"

# -- launching client-measure loads 
gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
cd memcache-perf-dynamic && 
  ./mcperf -s ${MEMCACHED_IP} --loadonly && 
  ./mcperf -s ${MEMCACHED_IP}  -a ${CLIENT_AGENT_IP}  \
  --noload -T 8 -C 8 -D 4 -Q 1000 -c 8 -t 10 \
  --qps_interval 2 --qps_min 5000 --qps_max 180000
"
