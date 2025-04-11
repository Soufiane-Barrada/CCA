#!/bin/bash 

set -e 

ZONE="europe-west1-b"
LOG_DIR="./part4_q1_logs"
mkdir -p $LOG_DIR

./create_cluster.sh

source ./get_node_infos.sh

gcloud compute scp ./memcached_init.sh ubuntu@$MEMCACHED_VM:~ --zone=$ZONE
gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "bash memcached_init.sh $MEMCACHED_IP"
gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "sudo systemctl restart memcached"

gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_AGENT_VM:~ --zone=$ZONE
gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "bash mcperf_init.sh"

gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_MEASURE_VM:~ --zone=$ZONE
gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "bash mcperf_init.sh"

gcloud compute ssh ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "
  cd memcache-perf-dynamic &&
  ./mcperf -T 8 -A &
"


THREADS=(1 1 2 2)
CORES=(1 2 1 2)

for i in {0..3}; do
    T=${THREADS[$i]}
    C=${CORES[$i]}

    for run in {1..3}; do
        echo "[Matteo Log] Running mcperf sweep for T=$T, C=$C (run $run)"

        gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
          sudo sed -i '/^-t /d' /etc/memcached.conf &&
          echo \"-t $T\" | sudo tee -a /etc/memcached.conf &&
          sudo systemctl restart memcached &&
          sleep 2 &&
          pid=\$(pidof memcached) &&
          CORES_LIST=\$(seq -s, 0 $((C - 1))) &&
          sudo taskset -a -cp \$CORES_LIST \$pid &&
          echo \"[Matteo Log] Memcached restarted with T=$T and pinned to \$CORES_LIST\"
        "

        gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
          cd memcache-perf-dynamic &&
          ./mcperf -s $MEMCACHED_IP --loadonly
        "

        gcloud compute ssh ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
          cd memcache-perf-dynamic &&
          ./mcperf -s $MEMCACHED_IP -a $CLIENT_AGENT_IP \
            --noload -T $T -C $T -D 4 -Q 1000 -c 8 -t 5 \
            --scan 5000:220000:5000
        " | tee "$LOG_DIR/scan_T${T}_C${C}_run${run}.txt"

        gcloud compute ssh ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
          pid=\$(pidof memcached) &&
          top -b -n 1 -p \$pid | grep memcached
        " > "$LOG_DIR/cpu_T${T}_C${C}_run${run}.txt"

        echo "[Matteo Log] Done T=$T, C=$C, run $run"
    done
done




