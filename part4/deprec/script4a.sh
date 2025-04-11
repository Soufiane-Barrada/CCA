#!/bin/bash

set -e 


#config 
CLUSTER_NAME="part4.k8s.local"
STATE_STORE="gs://cca-eth-2025-group-031-mpinto/"
ZONE="europe-west1-b"
LOG_DIR="p4_q1_logs"
THREAD_CORE_CONFIGS=(
  "1 1"
  "1 2"
  "2 1"
  "2 2"
)

mkdir -p "$LOG_DIR"

echo "[Matteo Log] Creating cluster..."
export KOPS_STATE_STORE=$STATE_STORE
PROJECT=$(gcloud config get-value project)
kops create -f part4.yaml
kops update cluster --name $CLUSTER_NAME --yes --admin
kops validate cluster --wait 10m

echo "[Matteo Log] Waiting for nodes to stabilize..."
sleep 15


echo "[INFO] Getting node IPs..."
kubectl get nodes -o wide > cluster_nodes.txt

MEMCACHED_VM=$(grep '^memcache-server' cluster_nodes.txt | awk '{print $1}')
MEMCACHED_IP=$(grep '^memcache-server' cluster_nodes.txt | awk '{print $6}')
CLIENT_AGENT_VM=$(grep '^client-agent' cluster_nodes.txt | awk '{print $1}')
CLIENT_AGENT_IP=$(grep '^client-agent' cluster_nodes.txt | awk '{print $6}')
CLIENT_MEASURE_VM=$(grep '^client-measure' cluster_nodes.txt | awk '{print $1}')
CLIENT_MEASURE_IP=$(grep '^client-measure' cluster_nodes.txt | awk '{print $6}')

echo "[Matteo Log] Memcached IP: $MEMCACHED_IP"
echo "[Matteo Log] Client agent IP: $CLIENT_AGENT_IP"


echo "[Matteo Log] Installing memcached on $MEMCACHED_VM..."
gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
  sudo apt update &&
  sudo apt install -y memcached libmemcached-tools &&
  sudo sed -i 's/-m .*/-m 1024/' /etc/memcached.conf &&
  sudo sed -i 's/-l .*/-l $MEMCACHED_IP/' /etc/memcached.conf &&
  sudo sed -i '/^-t /d' /etc/memcached.conf &&
  echo '[Matteo VM Log] Memcached installed and base configured.'
"


MCPERF_SCRIPT="sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources &&
  sudo apt-get update &&
  sudo apt-get install libevent-dev libzmq3-dev git make g++ --yes &&
  sudo apt-get build-dep memcached --yes &&
  git clone https://github.com/eth-easl/memcache-perf-dynamic.git &&
  cd memcache-perf-dynamic &&
  make &&
  echo '[Matteo VM Log] mcperf ready.'"

echo "[INFO] Installing mcperf on $CLIENT_AGENT_VM and $CLIENT_MEASURE_VM..."
gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "$MCPERF_SCRIPT"
gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "$MCPERF_SCRIPT"


for config in "${THREAD_CORE_CONFIGS[@]}"; do
  THREADS=$(echo $config | cut -d' ' -f1)
  CORES=$(echo $config | cut -d' ' -f2)

  echo "[Matteo Log] Running memcached with T=$THREADS, C=$CORES..."

  gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
    sudo systemctl stop memcached &&
    sudo sed -i '/^-t /d' /etc/memcached.conf &&
    echo '-t $THREADS' | sudo tee -a /etc/memcached.conf &&
    sudo systemctl restart memcached &&
    sleep 3 &&
    pid=\$(pidof memcached) &&
    sudo taskset -a -cp 0-$((CORES-1)) \$pid &&
    echo '[Matteo VM Log] Memcached running with T=$THREADS, C=$CORES'
  "

  echo "[Matteo Log] Pre-loading memcached..."
  gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
    cd memcache-perf-dynamic &&
    ./mcperf -s $MEMCACHED_IP --loadonly
  "

  echo "[Matteo Log] Running QPS sweep..."
  gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
    cd memcache-perf-dynamic &&
    ./mcperf -s $MEMCACHED_IP -a $CLIENT_AGENT_IP \
    --noload -T 8 -C 8 -D 4 -Q 1000 -c 8 -t 5 \
    --scan 5000:220000:5000
  " | tee "$LOG_DIR/memcached_T${THREADS}_C${CORES}.txt"

done

echo "[INFO] All experiments done. Logs saved in $LOG_DIR."


