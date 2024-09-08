packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}
variable "name" {
  type    = string
  default = "s3"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Region where EC2 should be deployed"
}

variable "profile" {
  type    = string
  default = "infra"
}

variable "source_ami" {
  type    = string
  default = "ami-0c7695b9a9d8612cd"
}

variable "ssh_username" {
  type    = string
  default = "ubuntu"
}

variable "ami_regions" {
  type        = list(string)
  default     = ["us-east-1"]
  description = "Regions where AMI should be copied"
}

# https://www.packer.io/plugins/builders/amazon/ebs
source "amazon-ebs" "eks" {
  profile               = var.profile
  ami_name              = "eks_${formatdate("YYYY_MM_DD_hh_mm_ss", timestamp())}"
  ami_description       = "AMI for EKS"
  region                = var.region
  force_deregister      = true
  force_delete_snapshot = true
  ami_regions           = var.ami_regions

  aws_polling {
    delay_seconds = 120
    max_attempts  = 50
  }

  instance_type = var.instance_type
  source_ami    = var.source_ami
  ssh_username  = var.ssh_username

  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp2"
  }
  tags = {
    Name = var.name
  }
}

build {
  sources = ["source.amazon-ebs.eks"]

  provisioner "shell" {
    environment_vars = [
      "CHECKPOINT_DISABLE=1"
    ]
    scripts = [
      "./ami/init.sh"
    ]
  }

  provisioner "file" {
    source      = "./ami/zfs_add_script.sh"
    destination = "/tmp/zfs_add_script.sh"
  }

  provisioner "file" {
    source      = "./ami/zfs_pool_init.sh"
    destination = "/tmp/zfspoolinit.sh"
  }
  
  provisioner "file" {
    source      = "./ami/heartbeat.sh"
    destination = "/tmp/heartbeat.sh"
  }

  provisioner "file" {
    source      = "./ssh/node_key.pub"
    destination = "/tmp/node_key.pub"
  }

  provisioner "shell" {
    environment_vars = [
      "CHECKPOINT_DISABLE=1"
    ]
    scripts = [
      "./ami/finish.sh"
    ]
  }
}