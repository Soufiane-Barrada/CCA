
sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
sudo apt-get update 
sudo apt-get install libevent-dev libzmq3-dev git make g++ --yes
sudo apt-get build-dep memcached --yes 
git clone https://github.com/eth-easl/memcache-perf-dynamic.git
cd memcache-perf-dynamic
make
