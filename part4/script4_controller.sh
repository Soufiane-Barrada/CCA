#!/bin/bash

set -e

# -- config --
CLUSTER_NAME="part4.k8s.local"
STATE_STORE="gs://cca-eth-2025-group-031-mpinto/"
ZONE="europe-west1-b"
CONTROLLER_SCRIPT="controller.py"
LOGGER_SCRIPT="scheduler_logger.py"
# -- end config --

echo "[Matteo Log] creating cluster"
./create_cluster.sh

echo "[Matteo Log] getting node information"
source ./get_node_infos.sh

echo "[Matteo Log] Setting up memcached on $MEMCACHED_VM"
gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "bash -s" < ./memcached_init.sh $MEMCACHED_IP

echo "[Matteo Log] Installing mcperf on $CLIENT_AGENT_VM"
gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "bash -s" < ./mcperf_init.sh

echo "[Matteo Log] Installing mcperf on $CLIENT_MEASURE_VM"
gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "bash -s" < ./mcperf_init.sh

echo "[Matteo Log] Launching mcperf agent on $CLIENT_AGENT_VM"
gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "cd memcache-perf-dynamic && ./mcperf -T 8 -A"

echo "[Matteo Log] Running mcperf load on $CLIENT_MEASURE_VM"
gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
  cd memcache-perf-dynamic &&
  ./mcperf -s $MEMCACHED_IP --loadonly &&
  ./mcperf -s $MEMCACHED_IP -a $CLIENT_AGENT_IP \
  --noload -T 8 -C 8 -D 4 -Q 1000 -c 8 -t 10 \
  --qps_interval 2 --qps_min 5000 --qps_max 180000
"

echo "[Matteo Log] Uploading controller scripts to $MEMCACHED_VM"
gcloud compute scp $CONTROLLER_SCRIPT $LOGGER_SCRIPT ubuntu@$MEMCACHED_VM:~ --zone=$ZONE

echo "[Matteo Log] Installing controller dependencies on $MEMCACHED_VM"
gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "bash -s" < ./build_dep.sh

echo "[Matteo Log] Running controller on $MEMCACHED_VM"
gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "python3 controller.py"

