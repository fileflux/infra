#!/bin/sh
# ZFS add script copy
sudo mv /tmp/zfs_add_script.sh /home/ubuntu/zfs_add_script.sh
sudo chmod +x /home/ubuntu/zfs_add_script.sh

# Heartbeat script copy
sudo mv /tmp/heartbeat.sh /usr/local/bin/heartbeat.sh
sudo chmod +x /usr/local/bin/heartbeat.sh

# SSH Key copy
sudo mv /tmp/node_key.pub /home/ubuntu/.ssh/authorized_keys
sudo chmod 600 /home/ubuntu/.ssh/authorized_keys

# ZFS pool init script copy
sudo mv /tmp/zfspoolinit.sh /usr/local/bin/zfspoolinit.sh
sudo chmod +x /usr/local/bin/zfspoolinit.sh

# Adding heartbeat service
sudo sh -c "echo '[Unit]
Description=Heartbeat every 10 seconds
After=network.target

[Service]
ExecStart=/usr/local/bin/heartbeat.sh
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target' >> /lib/systemd/system/heartbeat.service"

# Adding ZFS pool init service
sudo sh -c "echo '[Unit]
Description=ZFS Pool Init
After=network.target

[Service]
ExecStart=/usr/local/bin/zfspoolinit.sh
Type=oneshot
User=root

[Install]
WantedBy=multi-user.target' >> /lib/systemd/system/zfspoolinit.service"

sudo systemctl daemon-reload
sudo systemctl enable heartbeat zfspoolinit
echo "AMI Build Complete"