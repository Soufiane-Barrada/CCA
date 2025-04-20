
set -e

# Start
export PROJECT=`gcloud config get-value project`
ZONE="europe-west1-b"
source ./get_node_infos.sh


# Copy files into memcachd VM
gcloud compute scp ./controller.py ubuntu@$MEMCACHED_VM:~ --zone=$ZONE
gcloud compute scp ./scheduler_logger.py ubuntu@$MEMCACHED_VM:~ --zone=$ZONE

# Launch the Agent
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "
  cd memcache-perf-dynamic &&
  ./mcperf -T 8 -A
" &
AGENT_SSH_PID=$!

trap 'kill $AGENT_SSH_PID 2>/dev/null' EXIT





#                                         Here we should add a Loop
#Run the controller
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE < controller_runner.sh &
# Launch the Measure
gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
  cd memcache-perf-dynamic &&
  ./mcperf -s $MEMCACHED_IP --loadonly &&
  ./mcperf -s $MEMCACHED_IP -a $CLIENT_AGENT_IP \
  --noload -T 8 -C 8 -D 4 -Q 1000 -c 8 -t 1200 \
  --qps_interval 2 --qps_min 5000 --qps_max 180000 \
  --qps_seed 8 > measure.txt
"
gcloud compute scp ubuntu@$CLIENT_MEASURE_VM:~/memcache-perf-dynamic/measure.txt part4_q2_results/measure.txt --zone=$ZONE --ssh-key-file ~/.ssh/cloud-computing
gcloud compute scp ubuntu@$MEMCACHED_VM:~/log.txt part4_q2_results/jobs.txt --zone=$ZONE --ssh-key-file ~/.ssh/cloud-computing





# Done
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE < kill_process.sh &
