#!/bin/bash

# Variables
read -p "Enter the EBS volume size (in GB): " VOLUME_SIZE
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
REGION=$(sudo curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
AVAILABILITY_ZONE=$(sudo curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
VOLUME_TYPE="gp2" 
INSTANCE_ID=$(sudo curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
DEVICE_NAME="/dev/xvdf"  
ZPOOL_NAME="s3"

echo "Detected Region: $REGION"
echo "Detected Availability Zone: $AVAILABILITY_ZONE"
echo "Dected Instanct ID: $INSTANCE_ID"

find_available_device_name() {
  local device_prefix="/dev/xvd"
  
  # Currently attached devices
  local attached_devices=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query "Reservations[*].Instances[*].BlockDeviceMappings[*].DeviceName" \
    --output text)
  
  for letter in {f..z}; do
    local device_name="${device_prefix}${letter}"
    
    # Pending attachments check
    if echo "$attached_devices" | grep -q "$device_name"; then
      continue
    fi
    
    if [ ! -e "$device_name" ]; then
      echo "$device_name"
      return
    fi
  done

  echo "No available device names found" >&2
  exit 1
}

find_new_nvme_device() {
  local existing_nvme_devices=("$@")
  local current_nvme_devices=($(ls /dev/nvme*n1 | sort))  

  for device in "${current_nvme_devices[@]}"; do
    if [[ ! " ${existing_nvme_devices[@]} " =~ " ${device} " ]]; then
      echo "$device"
      return
    fi
  done

  echo "Error: No new NVMe device found" >&2
  exit 1
}

# Current NVMe's
existing_nvme_devices=($(ls /dev/nvme*n1 | sort))

# Create new volume
VOLUME_ID=$(aws ec2 create-volume \
  --region $REGION \
  --availability-zone $AVAILABILITY_ZONE \
  --size $VOLUME_SIZE \
  --volume-type $VOLUME_TYPE \
  --query 'VolumeId' \
  --output text)

echo "Created EBS Volume with ID: $VOLUME_ID"

# Checking new volume to become available
echo "Waiting for the volume to become available"
aws ec2 wait volume-available --volume-ids $VOLUME_ID

# Get device name
DEVICE_NAME=$(find_available_device_name)
echo "Device name: $DEVICE_NAME"

# Attaching EBS volume
aws ec2 attach-volume \
  --volume-id $VOLUME_ID \
  --instance-id $INSTANCE_ID \
  --device $DEVICE_NAME

echo "Attached EBS Volume $VOLUME_ID to Instance $INSTANCE_ID on $DEVICE_NAME"

# Waiting 
sleep 10

# Verification of volume attachment
ATTACHED=$(aws ec2 describe-volumes --volume-ids $VOLUME_ID --query 'Volumes[0].Attachments[0].State' --output text)

if [ "$ATTACHED" == "attached" ]; then
  echo "Volume $VOLUME_ID is successfully attached"
else
  echo "Failed to attach Volume $VOLUME_ID, status: $ATTACHED"
  exit 1
fi

# Check new NVMe
NEW_NVME_DEVICE=$(find_new_nvme_device "${existing_nvme_devices[@]}")
echo "New NVMe device found: $NEW_NVME_DEVICE"

# Add the new volume to the pool
sudo zpool add $ZPOOL_NAME $NEW_NVME_DEVICE

echo "Added $NEW_NVME_DEVICE to ZFS pool $ZPOOL_NAME"

# Get pool status
sudo zpool status $ZPOOL_NAME

echo "Script completed successfully"