#!/bin/bash 

MEMCACHED_IP=$1

sudo apt update 
sudo apt install -y memcached libmemcached-tools
sudo sed -i 's/-m .*/-m 1024/' /etc/memcached.conf
sudo sed -i "s/-l .*/-l $MEMCACHED_IP/" /etc/memcached.conf
sudo sed -i '/^-t /d' /etc/memcached.conf
