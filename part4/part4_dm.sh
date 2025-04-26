#!/bin/bash

set -ex

ZONE="europe-west1-b"
LOG_DIR="./part4_q1d_logs"
THREADS="$1"
DURATION=220
INTERVAL=5

if [ -z "$THREADS" ]; then
  echo "Usage: $0 <threads>"
  exit 1
fi

mkdir -p "$LOG_DIR"

#./create_cluster.sh
source ./get_node_infos.sh

echo "[Matteo Log] Uploading cpu_usage.py"
gcloud compute scp --ssh-key-file ~/.ssh/cloud-computing m_cpu_usage.py ubuntu@$MEMCACHED_VM:~ --zone=$ZONE

gcloud compute scp ./memcached_init.sh ubuntu@$MEMCACHED_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE \
  --command "bash memcached_init.sh $MEMCACHED_IP && sudo systemctl restart memcached"

gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_AGENT_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE \
  --command "bash mcperf_init.sh"

gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_MEASURE_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE \
  --command "bash mcperf_init.sh"

echo "[Matteo Log] Launching mcperf agent"
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE \
  --command "cd memcache-perf-dynamic && ./mcperf -T 8 -A" &
AGENT_SSH_PID=$!
trap 'echo "[Matteo Log] Cleaning up mcperf agent"; kill $AGENT_SSH_PID 2>/dev/null' EXIT

for C in 1 2; do
  echo "[Matteo Log] Running sweep for T=$THREADS, C=$C"

  gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
    sudo sed -i '/^-t /d' /etc/memcached.conf &&
    echo \"-t $THREADS\" | sudo tee -a /etc/memcached.conf &&
    sudo systemctl restart memcached &&
    sleep 2 &&
    pid=\$(pidof memcached) &&
    CORES_LIST=\$(seq -s, 0 \$((C - 1))) &&
    sudo taskset -a -cp \$CORES_LIST \$pid &&
    echo \"[Matteo Log] Memcached restarted with T=$THREADS, pinned to cores \$CORES_LIST\"
  "

  gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
    cd memcache-perf-dynamic &&
    ./mcperf -s $MEMCACHED_IP --loadonly
  "

  echo "[Matteo Log] Starting CPU monitor"
  gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
    pid=\$(pgrep memcached)
    python3 m_cpu_usage.py \$pid $DURATION $INTERVAL > cpu_usage.log
  " &
  CPU_SAMPLER_PID=$!

  echo "[Matteo Log] Starting mcperf sweep"
  gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
    cd memcache-perf-dynamic &&
    ./mcperf -s $MEMCACHED_IP -a $CLIENT_AGENT_IP \
      --noload -T $THREADS -C $THREADS -D 4 -Q 1000 -c 8 -t 5 \
      --scan 5000:220000:5000
  " | tee "$LOG_DIR/scan_T${THREADS}_C${C}_run3.txt"

  wait $CPU_SAMPLER_PID
  echo "[Matteo Log] mcperf + CPU monitoring complete"

  gcloud compute scp --ssh-key-file ~/.ssh/cloud-computing \
    ubuntu@$MEMCACHED_VM:~/cpu_usage.log "$LOG_DIR/cpu_T${THREADS}_C${C}_run3.txt" \
    --zone=$ZONE

done





