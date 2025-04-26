#!/bin/bash 



source nodes_info.txt

sudo apt update -y
sudo apt install -y memcached libmemcached-tools
sudo sed -i 's/-m .*/-m 1024/' /etc/memcached.conf
sudo sed -i "s/-l .*/-l $MEMCACHED_IP/" /etc/memcached.conf
sudo sed -i '/^-t /d' /etc/memcached.conf
echo "-t 2" | sudo tee -a /etc/memcached.conf
sleep 2
sudo systemctl restart memcached

sudo systemctl status memcached > check.txt
#MEMCACHED_IP=$1

#sudo apt update 
#sudo apt install -y memcached libmemcached-tools
#sudo sed -i 's/-m .*/-m 1024/' /etc/memcached.conf
#sudo sed -i "s/-l .*/-l $MEMCACHED_IP/" /etc/memcached.conf
#sudo sed -i '/^-t /d' /etc/memcached.conf
#echo \"-t 2\" | sudo tee -a /etc/memcached.conf
#sudo systemctl restart memcached

#sudo apt install -y python3-pip docker.io
#pip3 install psutil docker

#sudo usermod -aG docker ubuntu

#sudo docker pull anakli/cca:parsec_blackscholes
#sudo docker pull anakli/cca:parsec_canneal
#sudo docker pull anakli/cca:parsec_dedup
#sudo docker pull anakli/cca:parsec_ferret
#sudo docker pull anakli/cca:parsec_freqmine
#sudo docker pull anakli/cca:splash2x_radix
#sudo docker pull anakli/cca:parsec_vips