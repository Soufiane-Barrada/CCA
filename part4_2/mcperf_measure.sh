source nodes_info.txt
cd memcache-perf-dynamic
./mcperf -s $MEMCACHED_IP --loadonly
./mcperf -s $MEMCACHED_IP -a $CLIENT_AGENT_IP \
--noload -T 8 -C 8 -D 4 -Q 1000 -c 8 -t 1000 \
--qps_interval 10 --qps_min 5000 --qps_max 180000 \
--qps_seed 8 > measure.txt