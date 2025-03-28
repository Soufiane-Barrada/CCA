#!/bin/bash

#use this if cluster is not already up. 
#!!WARNING!! this does NOT kill the cluster after finishing the jobs. Needs to be done manually 


export PROJECT=$(gcloud config get-value project)
export KOPS_STATE_STORE=gs://cca-eth-2025-group-031-mpinto/

cd /Users/matteo/Desktop/cloud-comp-arch-project

echo "[MP] creating cluster" 

kops create -f part2b.yaml 
kops update cluster part2b.k8s.local --yes --admin 
kops validate cluster --wait 10m

kubectl get nodes -o wide > cluster_nodes_infos.txt
parsec_server=$(grep '^parsec-server' cluster_nodes_infos.txt | awk '{print $1}')

export PARSEC_SERVER="$parsec_server"

echo "[MP] labeling node $PARSEC_SERVER"

kubectl label nodes $PARSEC_SERVER cca-project-nodetype=parsec

CLUSTER_NAME="part2b.k8s.local"
ZONE="europe-west1-b"
THREADS=(1 2 4 8)
WORKLOADS=("blackscholes" "canneal" "dedup" "ferret" "freqmine" "radix" "vips")

LOG_DIR="part2b_logs"
mkdir -p "$LOG_DIR"

for workload in "${WORKLOADS[@]}"; do
  for n in "${THREADS[@]}"; do 
    echo "[MP] running $workload with $n threads"
    YAML_PATH="parsec-benchmarks/part2b/parsec-${workload}.yaml"
    TMP_YAML="tmp-${workload}.yaml"
    cp "$YAML_PATH" "$TMP_YAML"

    #set thread count 
    sed -i '' "s/-n [0-9]\+/-n $n/g" "$TMP_YAML"
    sed -i '' "s/simlarge/native/" "$TMP_YAML"

    echo "[MP] launching job" 
    kubectl create -f "$TMP_YAML"
    JOB_NAME="parsec-${workload}"

    echo "[MP]waiting for job $JOB_NAME to finish"
    kubectl wait --for=condition=complete job/$JOB_NAME --timeout=600s || echo "[WARN] $JOB_NAME may have failed"

    #save logs 
    POD_NAME=$(kubectl get pods --selector=job-name=$JOB_NAME -o jsonpath='{.items[*].metadata.name}')
    kubectl logs "$POD_NAME" > "$LOG_DIR/${workload}_${n}threads.log"

    #cleanup 
    kubectl delete jobs --all
    kubectl delete pods --all
    rm "$TMP_YAML"

    echo "[MP] Finished $workload with $n threads"
    echo ":)" 
    echo "-------------------------------"
  done 
done 













