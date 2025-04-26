
set -e

# Start

CLUSTER_NAME="part4.k8s.local"
ZONE="europe-west1-b"
CONTROLLER_SCRIPT="controller_v2.py"
LOGGER_SCRIPT="scheduler_logger.py"
export PROJECT=`gcloud config get-value project`
source ./get_node_infos.sh

# Kill processes if still running
echo "Soufiane 11"
gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "bash -s" < kill_process.sh &
echo "Soufiane 12"
gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "bash -s" < kill_process.sh &
echo "Soufiane 13"

# Copy files into memcachd VM
echo "Uploading controller scripts to $MEMCACHED_VM"
gcloud compute scp $CONTROLLER_SCRIPT $LOGGER_SCRIPT ubuntu@$MEMCACHED_VM:~ --zone=$ZONE

# Launch the Agent

echo "Launching mcperf agent on $CLIENT_AGENT_VM"
gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "cd memcache-perf-dynamic && ./mcperf -T 8 -A" &





#                                         Here we should add a Loop

# Launch the Measure
echo "[Matteo Log] Running mcperf load on $CLIENT_MEASURE_VM"
gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
  cd memcache-perf-dynamic &&
  ./mcperf -s $MEMCACHED_IP --loadonly &&
  ./mcperf -s $MEMCACHED_IP -a $CLIENT_AGENT_IP \
  --noload -T 8 -C 8 -D 4 -Q 1000 -c 8 -t 1200 \
  --qps_interval 10 --qps_min 5000 --qps_max 180000 \
  --qps_seed 8 > measure.txt
" &
sleep 5

echo "Running controller on $MEMCACHED_VM"
gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "python3 controller_v2.py"

# get results
gcloud compute scp ubuntu@$CLIENT_MEASURE_VM:~/memcache-perf-dynamic/measure.txt ./part4_q2_results/measure.txt --zone=$ZONE --ssh-key-file ~/.ssh/cloud-computing
gcloud compute scp ubuntu@$MEMCACHED_VM:~/log.txt ./part4_q2_results/jobs.txt --zone=$ZONE --ssh-key-file ~/.ssh/cloud-computing

# Done
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE < kill_process.sh &
