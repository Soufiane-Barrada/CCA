
set -e
export PROJECT=`gcloud config get-value project`
#cd /home/Soufiane/Desktop/CloudComputing/
cd /Users/ccylmichel/Desktop/CCA/

# Set desired node and resource parameters
export MEMCACHED_NODE="node-b-2core"
export MEMCACHED_CORES="0-1"
export MEMCACHED_THREADS=2

export BLACKSCHOLES_NODE="node-c-4core"
export BLACKSCHOLES_CORES="0-3"
export BLACKSCHOLES_THREADS=4

export RADIX_NODE="node-a-2core"
export RADIX_CORES="0-1"
export RADIX_THREADS=2

export CANNEAL_NODE="node-d-4core"
export CANNEAL_CORES="0-3"
export CANNEAL_THREADS=4

export DEDUP_NODE="node-a-2core"
export DEDUP_CORES="0-1"
export DEDUP_THREADS=2

export FERRET_NODE="node-c-4core"
export FERRET_CORES="0-3"
export FERRET_THREADS=4

export FREQMINE_NODE="node-c-4core"
export FREQMINE_CORES="0-2"
export FREQMINE_THREADS=4

export VIPS_NODE="node-c-4core"
export VIPS_CORES="3"
export VIPS_THREADS=2

envsubst < ./CCA/part3/yaml_files/memcache.yaml > ./CCA/part3/yaml_files/memcache-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-blackscholes.yaml > ./CCA/part3/yaml_files/parsec-blackscholes-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-canneal.yaml > ./CCA/part3/yaml_files/parsec-canneal-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-dedup.yaml > ./CCA/part3/yaml_files/parsec-dedup-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-ferret.yaml > ./CCA/part3/yaml_files/parsec-ferret-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-freqmine.yaml > ./CCA/part3/yaml_files/parsec-freqmine-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-radix.yaml > ./CCA/part3/yaml_files/parsec-radix-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-vips.yaml > ./CCA/part3/yaml_files/parsec-vips-sub.yaml


#***************************************************************************


# Create the Kubernetes cluster
kops create -f cloud-comp-arch-project/part3.yaml
kops update cluster --name part3.k8s.local --yes --admin
kops validate cluster --wait 10m
kubectl get nodes -o wide > cluster_nodes_info.txt 

# Parse the cluster_nodes_info.txt to extract needed data
client_agent_a=$(grep '^client-agent-a' cluster_nodes_info.txt | awk '{print $1}')
client_agent_a_internal_ip=$(grep '^client-agent-a' cluster_nodes_info.txt | awk '{print $6}')
client_agent_b=$(grep '^client-agent-b' cluster_nodes_info.txt | awk '{print $1}')
client_agent_b_internal_ip=$(grep '^client-agent-b' cluster_nodes_info.txt | awk '{print $6}')
client_measure=$(grep '^client-measure' cluster_nodes_info.txt | awk '{print $1}')
node_a=$(grep '^node-a' cluster_nodes_info.txt | awk '{print $1}')
node_b=$(grep '^node-b' cluster_nodes_info.txt | awk '{print $1}')
node_c=$(grep '^node-c' cluster_nodes_info.txt | awk '{print $1}')
node_d=$(grep '^node-d' cluster_nodes_info.txt | awk '{print $1}')


# Export the variables
export CLIENT_AGENT_A="$client_agent_a"
export CLIENT_AGENT_A_INTERNAL_IP="$client_agent_a_internal_ip"
export CLIENT_AGENT_B="$client_agent_b"
export CLIENT_AGENT_B_INTERNAL_IP="$client_agent_b_internal_ip"
export CLIENT_MEASURE="$client_measure"
export NODE_A="$node_a"
export NODE_B="$node_b"
export NODE_C="$node_c"
export NODE_D="$node_d"


# Write the variables into nodes_info.txt
cat <<EOF > nodes_info.txt
CLIENT_AGENT_A="$CLIENT_AGENT_A"
CLIENT_AGENT_A_INTERNAL_IP="$CLIENT_AGENT_A_INTERNAL_IP"
CLIENT_AGENT_B="$CLIENT_AGENT_B"
CLIENT_AGENT_B_INTERNAL_IP="$CLIENT_AGENT_B_INTERNAL_IP"
CLIENT_MEASURE="$CLIENT_MEASURE"
NODE_A="$NODE_A"
NODE_B="$NODE_B"
NODE_C="$NODE_C"
NODE_D="$NODE_D"
EOF

#***************************************************************************

# Launch memcached using Kubernetes
kubectl create -f ./CCA/part3/yaml_files/memcache-sub.yaml
kubectl expose pod some-memcached --name some-memcached-11211 --type LoadBalancer --port 11211 --protocol TCP
sleep 60
kubectl get service some-memcached-11211
kubectl get pods -o wide > memcached_info.txt

# Parse memcached_info.txt to extract IP
memcached_ip=$(grep '^some-memcached' memcached_info.txt | awk '{print $6}')

#Export the variable
export MEMCACHED_IP="$memcached_ip"

# write the Ip address a file
cat <<EOF > memcached_ip.txt
MEMCACHED_IP="$MEMCACHED_IP"
EOF

#***************************************************************************

# Initialize the client-agents and the client-measure VMs
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_A --zone europe-west1-b < ./CCA/part3/mcperf_init.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_B --zone europe-west1-b < ./CCA/part3/mcperf_init.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE --zone europe-west1-b < ./CCA/part3/mcperf_init.sh
gcloud compute scp ./nodes_info.txt ubuntu@$CLIENT_MEASURE:~/ --zone europe-west1-b --ssh-key-file ~/.ssh/cloud-computing
gcloud compute scp ./memcached_ip.txt ubuntu@$CLIENT_MEASURE:~/ --zone europe-west1-b --ssh-key-file ~/.ssh/cloud-computing

# Run the client-agents and the client-measure VMs
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_A --zone europe-west1-b < ./CCA/part3/mcperf_agent_a.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_B --zone europe-west1-b < ./CCA/part3/mcperf_agent_b.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE --zone europe-west1-b < ./CCA/part3/mcperf_measure.sh &

#***************************************************************************

# === node-a jobs ===
(
  kubectl create -f ./CCA/part3/yaml_files/parsec-vips-sub.yaml
  kubectl wait --for=condition=complete --timeout=600s job/parsec-vips

  kubectl create -f ./CCA/part3/yaml_files/parsec-dedup-sub.yaml
  kubectl wait --for=condition=complete --timeout=600s job/parsec-dedup

  kubectl create -f ./CCA/part3/yaml_files/parsec-radix-sub.yaml
  kubectl wait --for=condition=complete --timeout=600s job/parsec-radix
) &

# === node-c jobs ===
(
  kubectl create -f ./CCA/part3/yaml_files/parsec-ferret-sub.yaml
  kubectl wait --for=condition=complete --timeout=600s job/parsec-ferret

  kubectl create -f ./CCA/part3/yaml_files/parsec-blackscholes-sub.yaml
  kubectl wait --for=condition=complete --timeout=600s job/parsec-blackscholes
) &

# === node-d jobs ===
(
  kubectl create -f ./CCA/part3/yaml_files/parsec-canneal-sub.yaml
  kubectl wait --for=condition=complete --timeout=600s job/parsec-canneal

  kubectl create -f ./CCA/part3/yaml_files/parsec-freqmine-sub.yaml
  kubectl wait --for=condition=complete --timeout=600s job/parsec-freqmine
) &


sleep 300 #  10 mins
#**************************************************************************

#Kill the processes
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_A --zone europe-west1-b < ./CCA/part3/kill_process.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_B --zone europe-west1-b < ./CCA/part3/kill_process.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE --zone europe-west1-b < ./CCA/part3/kill_process.sh &
sleep 5

# Get the Results
kubectl get jobs > all_jobs.txt
#cd /home/Soufiane/Desktop/CloudComputing/CCA/part3/
cd /Users/ccylmichel/Desktop/CCA/CCA/part3 
sleep 30
gcloud compute scp ubuntu@$CLIENT_MEASURE:~/memcache-perf-dynamic/measure.txt "./part_3_results_group_031/measure.txt" --zone europe-west1-b --ssh-key-file ~/.ssh/cloud-computing
kubectl get pods -o json > ./part_3_results_group_031/results.json
python3 get_time.py ./part_3_results_group_031/results.json > ./part_3_results_group_031/time.txt

kubectl delete jobs --all
#kops delete cluster part3.k8s.local --yes




