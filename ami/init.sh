#!/bin/sh
# Install ZFS
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt install -y zfsutils-linux
sudo systemctl enable zfs.target zfs-mount 
sudo systemctl restart zfs.target zfs-mount