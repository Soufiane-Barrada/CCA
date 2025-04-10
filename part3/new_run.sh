# Use when the cluster is already up

set -e
export PROJECT=`gcloud config get-value project`
cd /home/Soufiane/Desktop/CloudComputing/
#cd /Users/ccylmichel/Desktop/CCA/
# Set desired node and resource parameters
export MEMCACHED_NODE="node-b-2core"
export MEMCACHED_CORES="0"
export MEMCACHED_THREADS=1

export BLACKSCHOLES_NODE="node-a-2core"
export BLACKSCHOLES_CORES="0-1"
export BLACKSCHOLES_THREADS=2

export RADIX_NODE="node-a-2core"
export RADIX_CORES="0-1"
export RADIX_THREADS=2

export CANNEAL_NODE="node-c-4core"
export CANNEAL_CORES="0-3"
export CANNEAL_THREADS=4

export DEDUP_NODE="node-a-2core"
export DEDUP_CORES="0-1"
export DEDUP_THREADS=2

export FERRET_NODE="node-c-4core"
export FERRET_CORES="0-3"
export FERRET_THREADS=4

export FREQMINE_NODE="node-d-4core"
export FREQMINE_CORES="0-3"
export FREQMINE_THREADS=4

export VIPS_NODE="node-b-2core"
export VIPS_CORES="1"
export VIPS_THREADS=1
#*******************************

envsubst < ./CCA/part3/yaml_files/memcache.yaml > ./CCA/part3/yaml_files/memcache-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-blackscholes.yaml > ./CCA/part3/yaml_files/parsec-blackscholes-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-canneal.yaml > ./CCA/part3/yaml_files/parsec-canneal-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-dedup.yaml > ./CCA/part3/yaml_files/parsec-dedup-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-ferret.yaml > ./CCA/part3/yaml_files/parsec-ferret-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-freqmine.yaml > ./CCA/part3/yaml_files/parsec-freqmine-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-radix.yaml > ./CCA/part3/yaml_files/parsec-radix-sub.yaml
envsubst < ./CCA/part3/yaml_files/parsec-vips.yaml > ./CCA/part3/yaml_files/parsec-vips-sub.yaml

client_agent_a=$(grep '^client-agent-a' cluster_nodes_info.txt | awk '{print $1}')
client_agent_a_internal_ip=$(grep '^client-agent-a' cluster_nodes_info.txt | awk '{print $6}')
client_agent_b=$(grep '^client-agent-b' cluster_nodes_info.txt | awk '{print $1}')
client_agent_b_internal_ip=$(grep '^client-agent-b' cluster_nodes_info.txt | awk '{print $6}')
client_measure=$(grep '^client-measure' cluster_nodes_info.txt | awk '{print $1}')


export CLIENT_AGENT_A="$client_agent_a"
export CLIENT_AGENT_A_INTERNAL_IP="$client_agent_a_internal_ip"
export CLIENT_AGENT_B="$client_agent_b"
export CLIENT_AGENT_B_INTERNAL_IP="$client_agent_b_internal_ip"
export CLIENT_MEASURE="$client_measure"




# Run the client-agents and the client-measure VMs
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_A --zone europe-west1-b < ./CCA/part3/mcperf_agent_a.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_B --zone europe-west1-b < ./CCA/part3/mcperf_agent_b.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE --zone europe-west1-b < ./CCA/part3/mcperf_measure.sh &


kubectl create -f ./CCA/part3/yaml_files/parsec-vips-sub.yaml
# === node-a jobs ===
(
  kubectl create -f ./CCA/part3/yaml_files/parsec-blackscholes-sub.yaml
  
  kubectl create -f ./CCA/part3/yaml_files/parsec-radix-sub.yaml
  kubectl wait --for=condition=complete --timeout=600s job/parsec-radix

  kubectl create -f ./CCA/part3/yaml_files/parsec-dedup-sub.yaml

  
) &

# === node-c jobs ===
(
  kubectl create -f ./CCA/part3/yaml_files/parsec-ferret-sub.yaml

  kubectl create -f ./CCA/part3/yaml_files/parsec-canneal-sub.yaml

  
) &

# === node-d jobs ===
(
  kubectl create -f ./CCA/part3/yaml_files/parsec-freqmine-sub.yaml
  
) &


sleep 300 #  5 mins


#**************************************************************************

#Kill the processes
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_A --zone europe-west1-b < ./CCA/part3/kill_process.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_AGENT_B --zone europe-west1-b < ./CCA/part3/kill_process.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$CLIENT_MEASURE --zone europe-west1-b < ./CCA/part3/kill_process.sh &
sleep 5

# Get the Results
kubectl get jobs > all_jobs.txt
cd /home/Soufiane/Desktop/CloudComputing/CCA/part3/
#cd /Users/ccylmichel/Desktop/CCA/CCA/part3 
sleep 30
gcloud compute scp ubuntu@$CLIENT_MEASURE:~/memcache-perf-dynamic/measure.txt "./part_3_results_group_031/measure.txt" --zone europe-west1-b --ssh-key-file ~/.ssh/cloud-computing
kubectl get pods -o json > ./part_3_results_group_031/results.json
python3 get_time.py ./part_3_results_group_031/results.json > ./part_3_results_group_031/time.txt

kubectl delete jobs --all