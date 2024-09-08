#!/bin/bash

# Creating ZFS pool
sudo zpool create -m /s3 s3 /dev/nvme1n1

# Disable service after running
sudo systemctl disable zfspoolinit.service

# Remove the service file so it doesn't run again
sudo rm -rf /lib/systemd/system/zfspoolinit.service
