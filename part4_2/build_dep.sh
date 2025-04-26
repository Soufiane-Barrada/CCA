#!/bin/bash 

sudo apt update -y
sudo apt install -y \
    python3-pip \
    docker.io \
    python3-docker \
    python3-psutil
sudo usermod -aG docker ubuntu
