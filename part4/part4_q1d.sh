#!/bin/bash 

set -ex 

ZONE="europe-west1-b"
LOG_DIR="./part4_q1_logs"
mkdir -p $LOG_DIR

./create_cluster.sh

source ./get_node_infos.sh

gcloud compute scp ./memcached_init.sh ubuntu@$MEMCACHED_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "bash memcached_init.sh $MEMCACHED_IP"
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "sudo systemctl restart memcached"
echo "[Matteo Log] memcached_init.sh complete"

gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_AGENT_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "bash mcperf_init.sh"
echo "[Matteo Log] mcperf_init.sh complete on agent"

gcloud compute scp ./mcperf_init.sh ubuntu@$CLIENT_MEASURE_VM:~ --zone=$ZONE
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "bash mcperf_init.sh"
echo "[Matteo Log] mcperf_init.sh complete on measure"


echo "[Matteo Log] launching mcperf agent in background ssh session"

gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_VM --zone=$ZONE --command "
  cd memcache-perf-dynamic &&
  ./mcperf -T 8 -A
" &
AGENT_SSH_PID=$!

trap 'echo "[Matteo Log] Cleaning up mcperf agent"; kill $AGENT_SSH_PID 2>/dev/null' EXIT


THREADS=(2 2)
CORES=(1 2)

for i in {0..1}; do
    T=${THREADS[$i]}
    C=${CORES[$i]}

    for run in {1..1}; do
        echo "[Matteo Log] Running mcperf sweep for T=$T, C=$C (run $run)"

        # Configure memcached threads and CPU affinity
        gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
          sudo sed -i '/^-t /d' /etc/memcached.conf &&
          echo \"-t $T\" | sudo tee -a /etc/memcached.conf &&
          sudo systemctl restart memcached &&
          sleep 2 &&
          pid=\$(pidof memcached) &&
          CORES_LIST=\$(seq -s, 0 $((C - 1))) &&
          sudo taskset -a -cp \$CORES_LIST \$pid &&
          echo \"[Matteo Log] Memcached restarted with T=$T and pinned to \$CORES_LIST\"
        "
        echo "[Matteo Log] memcached taskset complete"

        # Load test
        gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
          cd memcache-perf-dynamic &&
          ./mcperf -s $MEMCACHED_IP --loadonly
        "
        echo "[Matteo Log] measure load complete"
        
        # Start CPU logging on memcached server
        gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
          nohup bash -c '
            while true; do
              date +\"%s\" >> cpu_T${T}_C${C}_run${run}.txt
              top -bn1 | grep \"^%Cpu\" >> cpu_T${T}_C${C}_run${run}.txt
              sleep 5
            done
          ' > cpu_logger.out 2>&1 &
          echo \$! > cpu_logger.pid
        "

        # Run the actual benchmark
        gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE_VM --zone=$ZONE --command "
          cd memcache-perf-dynamic &&
          ./mcperf -s $MEMCACHED_IP -a $CLIENT_AGENT_IP \
            --noload -T $T -C $T -D 4 -Q 1000 -c 8 -t 5 \
            --scan 5000:220000:5000
        " | tee "$LOG_DIR/scan_T${T}_C${C}_run${run}.txt"

        # Stop CPU logging
        gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEMCACHED_VM --zone=$ZONE --command "
          kill \$(cat cpu_logger.pid) && rm cpu_logger.pid
        "

        # Download CPU log
        gcloud compute scp ubuntu@$MEMCACHED_VM:cpu_T${T}_C${C}_run${run}.txt $LOG_DIR/ --zone=$ZONE

        


        # Download the CPU log
        gcloud compute scp ubuntu@$MEMCACHED_VM:cpu_T${T}_C${C}_run${run}.txt $LOG_DIR/ --zone=$ZONE

        echo "[Matteo Log] Done T=$T, C=$C, run $run"
    done
done
