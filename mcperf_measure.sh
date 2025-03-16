source memcached_ip.txt
source nodes_info.txt
cd memcache-perf
./mcperf -s MEMCACHED_IP --loadonly
./mcperf -s MEMCACHED_IP -a INTERNAL_AGENT_IP \
--noload -T 8 -C 8 -D 4 -Q 1000 -c 8 -t 5 -w 2\
--scan 5000:80000:5000 > measure.txt
