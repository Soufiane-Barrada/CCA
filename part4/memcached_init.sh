#!/bin/bash 

MEMCACHED_IP=$1

sudo apt update 
sudo apt install -y memcached libmemcached-tools
sudo sed -i 's/-m .*/-m 1024/' /etc/memcached.conf
sudo sed -i "s/-l .*/-l $MEMCACHED_IP/" /etc/memcached.conf
sudo sed -i '/^-t /d' /etc/memcached.conf
echo \"-t 2\" | sudo tee -a /etc/memcached.conf
sudo systemctl restart memcached


MEMCACHED_PID=$(pidof memcached)
sudo taskset -a -cp 0-1 $MEMCACHED_PID

sudo apt -y install python3-pip
pip3 install psutil docker

sudo usermod -aG docker ubuntu