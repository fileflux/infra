#!/bin/bash

# Variables
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
NODE_NAME=$(sudo curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
ZPOOL_NAME="s3"
NODE_IP=$(hostname -I | awk '{print $1}')
FLASK_API="http://$NODE_IP:32187/heartbeat"

while true; do
  TOTAL_SPACE=$(zfs get -Hp -o value available $ZPOOL_NAME)
  AVAILABLE_SPACE=$(zfs get -Hp -o value available $ZPOOL_NAME)

  # Send POST request via NodePort
  curl -X POST $FLASK_API -H "Content-Type: application/json" -d '{
      "node_name": "'$NODE_NAME'",
      "zpool_name": "'$ZPOOL_NAME'",
      "total_space": '$TOTAL_SPACE',
      "available_space": '$AVAILABLE_SPACE'
  }'
   sleep 10
done