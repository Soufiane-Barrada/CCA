
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