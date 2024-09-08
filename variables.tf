variable "profile" {
  type        = string
  default     = "infra"
  description = "AWS profile in which the resources will be deployed"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Region where the resources will be deployed"
}

variable "vpc_name" {
  type    = string
  default = "s3"
}

variable "vpccidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR Block"
  validation {
    condition     = contains(["10.0.0.0/16", "192.168.0.0/16", "172.31.0.0/16"], var.vpccidr)
    error_message = "Please enter a valid CIDR. Allowed values are 10.0.0.0/16, 192.168.0.0/16 and 172.31.0.0/16"
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  description = "Public subnets for VPC"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  description = "Public subnets for VPC"
}

variable "azs" {
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
  description = "AZs to be used"
}

variable "aws_cluster_security_group_name" {
  type    = string
  default = "cluster"
}

variable "cluster_ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_block  = string
    description = string
  }))

  default = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
      description = "All Inbound"
    }
  ]
}

variable "cluster_egress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_block  = string
    description = string
  }))

  default = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
      description = "All Outbound"
    }
  ]
}

variable "aws_node_security_group_name" {
  type    = string
  default = "node"
}

variable "node_ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    description = string
  }))

  default = [
    {
      from_port   = 1024
      to_port     = 65535
      protocol    = "TCP"
      description = "All Inbound"
    }
  ]
}

variable "node_egress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_block  = string
    description = string
  }))

  default = [
    {
      from_port   = 0
      to_port     = 65535
      protocol    = "-1"
      cidr_block  = "0.0.0.0/0"
      description = "All Outbound"
    }
  ]
}

variable "cluster_name" {
  type    = string
  default = "s3"
}

variable "node_group_name" {
  type    = string
  default = "s3_node_group"
}

variable "k8_cluster_version" {
  type    = string
  default = "1.30"
}

variable "eks_role" {

  type    = string
  default = "s3_eks_role"
}

variable "family" {

  type    = string
  default = "ipv4"
}

variable "service_account_name" {
  type    = string
  default = "cluster-autoscaler"
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "desired_size" {
  type    = number
  default = 1
}

variable "max_unavailable_number" {
  type    = string
  default = "1"
}

variable "authentication_mode" {
  type    = string
  default = "API_AND_CONFIG_MAP"
}

variable "cluster_tags" {
  type = map(string)
  default = {
    "project" = "s3"
    "name"    = "infra"
  }
}

variable "nsquota" {
  type    = string
  default = "nsquota"
}

variable "cloudflare_email" {
  type    = string
}
variable "cloudflare_api_key" {
  type    = string
}

variable "domain_name" {
  type    = string
}

variable "grafana_domain_name" {
  type    = string
}

variable "cloudflare_zone_id" {
  type    = string
}

variable "cockroachdb_release_name" {
  type    = string
  default = "crdb"
}

variable "ami_id" {
  type    = string
  default = "ami-07610b016ff4da177"
}

variable "db_name" {
  type    = string
  default = "s3"
}

variable "db_username" {
  type    = string
  default = "s3"
}

variable "db_password" {
  type    = string
}

variable "db_host" {
  type    = string
  default = "cockroachdb-public.crdb.svc.cluster.local"
}

variable "bastion_ami_id" {
  type    = string
  default = "ami-0182f373e66f89c85"
}

