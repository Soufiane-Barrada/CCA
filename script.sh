
export PROJECT=`gcloud config get-value project`
# gcloud config set account sbarrada@ethz.ch
# gcloud auth login
# gcloud config set project $PROJECT
# gcloud auth application-default login


cd /home/Soufiane/Desktop/CloudComputing/

# Create the Kubernetes cluster
kops create -f cloud-comp-arch-project/part1.yaml 
#add my ssh key as a login key for the nodes
kops create secret --name part1.k8s.local sshpublickey admin -i ~/.ssh/cloud-computing.pub
# Deploy the cluster
kops update cluster --name part1.k8s.local --yes --admin
# Validate the cluster
kops validate cluster --wait 10m
# Write nodes status and details in cluster_nodes_info.txt
kubectl get nodes -o wide > cluster_nodes_info.txt

# Parse the cluster_nodes_info.txt to extract needed data
client_agent=$(grep '^client-agent' cluster_nodes_info.txt | awk '{print $1}')
client_agent_internal_ip=$(grep '^client-agent' cluster_nodes_info.txt | awk '{print $6}')
client_measure=$(grep '^client-measure' cluster_nodes_info.txt | awk '{print $1}')

# Export the variables
export CLIENT_AGENT="$client_agent"
export CLIENT_AGENT_INTERNAL_IP="$client_agent_internal_ip"
export CLIENT_MEASURE="$client_measure"

# Write the variables into nodes_info.txt
cat <<EOF > nodes_info.txt
CLIENT_AGENT="$CLIENT_AGENT"
CLIENT_AGENT_INTERNAL_IP="$CLIENT_AGENT_INTERNAL_IP"
CLIENT_MEASURE="$CLIENT_MEASURE"
EOF


#***************************************************************************

# Launch memcached using Kubernetes
kubectl create -f cloud-comp-arch-project/memcache-t1-cpuset.yaml
kubectl expose pod some-memcached --name some-memcached-11211 --type LoadBalancer --port 11211 --protocol TCP
sleep 60
kubectl get service some-memcached-11211
kubectl get pods -o wide > memcached_info.txt

# Parse memcached_info.txt to extract IP
memcached_ip=$(grep '^some-memcached' memcached_info.txt | awk '{print $6}')

#Export the variable
export MEMCACHED_IP="$memcached_ip"

# write the Ip address into some file
cat <<EOF > memcached_ip.txt
MEMCACHED_IP="$MEMCACHED_IP"
EOF

#***************************************************************************

# Initialize the client-agent and the client-measure
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$AGENT_NAME --zone europe-west1-b < ./CCA/mcperf_init.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEASURE_NAME --zone europe-west1-b < ./CCA/mcperf_init.sh
gcloud compute scp ./memcached_ip.txt ubuntu@$MEASURE_NAME:~/ --zone europe-west1-b --ssh-key-file ~/.ssh/cloud-computing
gcloud compute scp ./nodes_info.txt ubuntu@$MEASURE_NAME:~/ --zone europe-west1-b --ssh-key-file ~/.ssh/cloud-computing

# Run both
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$AGENT_NAME --zone europe-west1-b < ./CCA/mcperf_agent.sh &
gcloud compute ssh --ssh-key-file ~/.ssh/cloud-computing ubuntu@$MEASURE_NAME --zone europe-west1-b < ./CCA/mcperf_measure.sh
sleep 100
gcloud compute scp ubuntu@$MEASURE_NAME:~/memcache-perf/measure.txt ./memcached.txt --zone europe-west1-b --ssh-key-file ~/.ssh/cloud-computing
