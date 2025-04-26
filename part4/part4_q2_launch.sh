set -e
# gcloud config set account sbarrada@ethz.ch
# gcloud auth login
# gcloud config set project $PROJECT
# gcloud auth application-default login

# Start
export PROJECT=`gcloud config get-value project`
ZONE="europe-west1-b"

# Initialize cluster
./create_cluster.sh
source ./get_node_infos.sh


# Initialize memcachd VM
gcloud compute scp ./memcached_init.sh ubuntu@$MEMCACHED_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "bash memcached_init.sh $MEMCACHED_IP"
#gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "sudo systemctl restart memcached"

# Initialize Agent VM
gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_AGENT_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "bash mcperf_init.sh"

# intialize Measure VM
gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_MEASURE_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "bash mcperf_init.sh"


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
  --qps_interval 10 --qps_min 5000 --qps_max 180000 \
  --qps_seed 8 > measure.txt
"

$ ./mcperf -s INTERNAL_MEMCACHED_IP --loadonly
$ ./mcperf -s INTERNAL_MEMCACHED_IP -a INTERNAL_AGENT_IP \
--noload -T 8 -C 8 -D 4 -Q 1000 -c 8 -t 1800 \
--qps_interval 10 --qps_min 5000 --qps_max 180000

gcloud compute scp ubuntu@$CLIENT_MEASURE_VM:~/memcache-perf-dynamic/measure.txt ./part4_q2_results/measure.txt --zone=$ZONE --ssh-key-file ~/.ssh/cloud-computing
gcloud compute scp ubuntu@$MEMCACHED_VM:~/log.txt ./part4_q2_results/jobs.txt --zone=$ZONE --ssh-key-file ~/.ssh/cloud-computing





# Done
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE < kill_process.sh &

# kops delete cluster --name part4.k8s.local --yes