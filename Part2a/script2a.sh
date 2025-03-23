
# Deploy the cluster. Once deploy TODO: PUT IN COMMENTS, if run the script again 
#***************************************************************************

export PROJECT=`gcloud config get-value project`
# change ethz_id
export KOPS_STATE_STORE=gs://cca-eth-2025-group-031-cmichel/

# Path to where is part2a.yaml 
cd /Users/ccylmichel/Desktop/CCA/cloud-comp-arch-project   

# Create the Kubernetes cluster
kops create -f part2a.yaml
# Deploy the cluster
kops update cluster part2a.k8s.local --yes --admin
# Validate the cluster
kops validate cluster --wait 10m
# Write nodes status and details in cluster_nodes_info.txt
kubectl get nodes -o wide > cluster_nodes_info.txt


# Parse the cluster_nodes_info.txt to extract needed data
parsec_server=$(grep '^parsec-server' cluster_nodes_info.txt | awk '{print $1}')

# Export the variables
export PARSEC_SERVER="$parsec_server"


# Initialize the parsec-server 
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$PARSEC_SERVER --zone europe-west1-b < ./CCA/mcperf_init.sh &

# Assign the appropriate label to the parsec node 
kubectl label nodes $PARSEC_SERVER cca-project-nodetype=parsec

# Once the cluster is deploy you can just run the script below and put everything in comments above.
#***************************************************************************

# All the values of workloads and Interferences
WORKLOADS=("blackscholes" "canneal" "dedup" "ferret" "freqmine" "radix" "vips")
INTERFERENCES=("cpu" "l1d" "l1i" "l2" "llc" "membw")

for workload in "${WORKLOADS[@]}"; do

    # Create interference and !! Change ibench-cpu to another interference !!
    kubectl create -f interference/ibench-cpu.yaml
    # Wait for interference to be ready
    sleep 5
    # Create benchmark 
    kubectl create -f parsec-benchmarks/part2a/parsec-${workload}.yaml

    # Wait for job to complete
    JOB_NAME="parsec-${workload}"
    echo "[WAIT] Waiting for $JOB_NAME to complete..."
    kubectl wait --for=condition=complete job/$JOB_NAME --timeout=600s || echo "[WARN] $JOB_NAME may have failed"

    # Get logs
    POD_NAME=$(kubectl get pods --selector=job-name=$JOB_NAME -o jsonpath='{.items[*].metadata.name}')
    kubectl logs "$POD_NAME" > ibench-cpu_${JOB_NAME}.txt

    # Cleanup
    kubectl delete jobs --all
    kubectl delete pods --all
    echo "----------------------------------------"

done

# Optional: delete the cluster to save credits
# kops delete cluster part2a.k8s.local --yes



