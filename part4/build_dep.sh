#!/bin/bash 

sudo apt update
sudo apt install -y python3-pip docker.io
sudo usermod -aG docker ubuntu
pip3 install psutil
