source memcached_ip.txt
source nodes_info.txt
cd memcache-perf-dynamic
./mcperf -s $MEMCACHED_IP --loadonly
./mcperf -s $MEMCACHED_IP -a $CLIENT_AGENT_A_INTERNAL_IP -a $CLIENT_AGENT_B_INTERNAL_IP \
--noload -T 6 -C 4 -D 4 -Q 1000 -c 4 -t 10 \
--scan 30000:30500:5 > measure.txt