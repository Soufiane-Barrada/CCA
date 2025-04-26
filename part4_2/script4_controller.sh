#!/bin/bash
# gcloud config set account sbarrada@ethz.ch
# gcloud auth login
# gcloud config set project $PROJECT
# gcloud auth application-default login
set -e

CLUSTER_NAME="part4.k8s.local"
ZONE="europe-west1-b"
CONTROLLER_SCRIPT="controller.py"
LOGGER_SCRIPT="scheduler_logger.py"

#*************************************************************************
echo "[Log] creating cluster"
./create_cluster.sh

echo "[Log] getting node information"
kubectl get nodes -o wide > cluster_nodes_infos.txt

MEMCACHED_VM=$(grep '^memcache-server' cluster_nodes_infos.txt | awk '{print $1}')
MEMCACHED_IP=$(grep '^memcache-server' cluster_nodes_infos.txt | awk '{print $6}')
CLIENT_AGENT_VM=$(grep '^client-agent' cluster_nodes_infos.txt | awk '{print $1}')
CLIENT_AGENT_IP=$(grep '^client-agent' cluster_nodes_infos.txt | awk '{print$6}')
CLIENT_MEASURE_VM=$(grep '^client-measure' cluster_nodes_infos.txt | awk '{print $1}')
CLIENT_MEASURE_IP=$(grep '^client-measure' cluster_nodes_infos.txt | awk '{print $6}')

# Export the variables
export MEMCACHED_VM="$MEMCACHED_VM"
export MEMCACHED_IP="$MEMCACHED_IP"
export CLIENT_AGENT_VM="$CLIENT_AGENT_VM"
export CLIENT_AGENT_IP="$CLIENT_AGENT_IP"
export CLIENT_MEASURE_VM="$CLIENT_MEASURE_VM"
export CLIENT_MEASURE_IP="$CLIENT_MEASURE_IP"


# Write the variables into nodes_info.txt
cat <<EOF > nodes_info.txt
MEMCACHED_VM="$MEMCACHED_VM"
MEMCACHED_IP="$MEMCACHED_IP"
CLIENT_AGENT_VM="$CLIENT_AGENT_VM"
CLIENT_AGENT_IP="$CLIENT_AGENT_IP"
CLIENT_MEASURE_VM="$CLIENT_MEASURE_VM"
CLIENT_MEASURE_IP="$CLIENT_MEASURE_IP"
EOF

#**************************************************************************



echo "[Log] Setting up memcached on $MEMCACHED_VM"
gcloud compute scp ./memcached_init.sh ubuntu@$MEMCACHED_VM:~ --zone=$ZONE
gcloud compute scp ./nodes_info.txt ubuntu@$MEMCACHED_VM:~/ --zone europe-west1-b
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "bash memcached_init.sh"

echo "[Log] Installing mcperf on $CLIENT_AGENT_VM"
gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_AGENT_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "bash mcperf_init.sh"

echo "[Log] Installing mcperf on $CLIENT_MEASURE_VM"
gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_MEASURE_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "bash mcperf_init.sh"

echo "[Log] Installing controller dependencies on $MEMCACHED_VM"
gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "bash -s" < ./build_dep.sh

echo "[Log] Uploading controller scripts to $MEMCACHED_VM"
gcloud compute scp $CONTROLLER_SCRIPT $LOGGER_SCRIPT ubuntu@$MEMCACHED_VM:~ --zone=$ZONE

#**************************************************************************
echo "[Log] Launching mcperf agent on $CLIENT_AGENT_VM"
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE < ./mcperf_agent.sh &

echo "[Log] Running controller on $MEMCACHED_VM"
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE < ./start_controller.sh &

echo "[Log] Running mcperf measure on $CLIENT_MEASURE_VM"
gcloud compute scp ./nodes_info.txt ubuntu@$CLIENT_MEASURE_VM:~/ --zone europe-west1-b
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE < ./mcperf_measure.sh 

#**************************************************************************




gcloud compute scp ubuntu@$CLIENT_MEASURE_VM:~/memcache-perf-dynamic/measure.txt ./results/measure.txt --zone=$ZONE --ssh-key-file ~/.ssh/cloud-computing
gcloud compute scp ubuntu@$MEMCACHED_VM:~/log.txt ./results/jobs.txt --zone=$ZONE --ssh-key-file ~/.ssh/cloud-computing

# Done
gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "bash -s" < kill_process.sh &


# kops delete cluster --name part4.k8s.local --yes

