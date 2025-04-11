kubectl get nodes -o wide > cluster_nodes_infos.txt

MEMCACHED_VM=$(grep '^memcache-server' cluster_nodes_infos.txt | awk '{print $1}')
MEMCACHED_IP=$(grep '^memcache-server' cluster_nodes_infos.txt | awk '{print $6}')
CLIENT_AGENT_VM=$(grep '^client-agent' cluster_nodes_infos.txt | awk '{print $1}')
CLIENT_AGENT_IP=$(grep '^client-agent' cluster_nodes_infos.txt | awk '{print$6}')
CLIENT_MEASURE_VM=$(grep '^client-measure' cluster_nodes_infos.txt | awk '{print $1}')
CLIENT_MEASURE_IP=$(grep '^client-measure' cluster_nodes_infos.txt | awk '{print $6}')
echo "[Matteo Log] Memcached internal IP is: $MEMCACHED_IP"
echo "[Matteo Log] Memcached VM name is: $MEMCACHED_VM"
echo "[Matteo Log] client agent internal IP is: $CLIENT_AGENT_IP"
echo "[Matteo Log] client agent VM name is: $CLIENT_AGENT_VM"
echo "[Matteo Log] client measure intenral IP is: $CLIENT_MEASURE_IP"
echo "[Matteo Log] client measure VM name is: $CLIENT_MEASURE_VM"
