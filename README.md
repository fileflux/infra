# FileFlux EKS Infrastructure

This repository contains Terraform and other necessary code to set up a highly available and scalable Amazon EKS (Elastic Kubernetes Service) cluster and its associated infrastructure components on AWS to host the various microservices that make up the FileFlux application. 

## Prerequisites
- AWS CLI installed and configured with a profile that has the necessary permissions to create the resources defined in the Terraform code [AWS CLI Configuration guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)
- Install Terraform: [Terraform Installation Guide](https://learn.hashicorp.com/terraform/getting-started/install.html)
- Install Packer: [Packer Installation Guide](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli)
- Install Kubernetes CLI (kubectl): [kubectl Installation Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Repository Structure

```plaintext
infra/             
├── ami/
│   ├── ami.pkr.hcl
│   ├── init.sh
│   ├── heartbeat.sh    
│   ├── finish.sh
│   ├── zfs_add_script.sh
│   ├── zfs_pool_init.sh     
│   └── README.md
|── grafana_dashboards/
│   ├── k8s.json
│   └── s3.json
|   └── zfs.json
|── argocd.tf
|── bastion.tf
|── cluster_addons.tf
|── dns.tf
|── eks.tf
|── elastisearch.tf
|── elasticsearch.yaml
|── fargate.tf
|── fluentbit.tf
|── grafana.tf
|── iam.tf
|── istoio.tf
|── istio.yaml
|── k8_ns.tf
|── k8_provider.tf
|── karpenter.tf
|── kibana.tf
|── kibana.yaml
|── kms.tf
|── logstash.tf
|── logstash.yaml
|── network.tf
|── packer.tf
|── priorityclass.tf
|── prometheus.tf
|── prometheus.yaml
|── provider.tf
|── secrets.tf
├── README.md 
|── sg.tf
|── ssh.tf
|── ssl.tf           
├── variables.tf 
```

## Infrastructure Components
- A VPC with 3 public and 3 private subnets across 3 availability zones
- 3 NAT Gateways to allow the aforementioned private subnets to allow outbound internet access and an internet gateway for the public subnets
- EKS Cluster based on Kubernetes version 1.30 with cluster add-ons such as Secrets Store CSI Driver, EBS CSI Driver, VPC-CNI, and Kube-proxy, etc with high priority classes for critical add-ons
- IAM policies and roles for the EKS cluster and its worker nodes to interact with other AWS services such as KMS, CloudWatch, Route53, SNS, etc and to allow Kubernetes Service Accounts (IRSA) to assume roles and interact with AWS services
- Security Groups for the EKS cluster, worker nodes, and other resources
- Bastion host for SSH access to EKS worker nodes in private subnets
- SSH key pairs for the bastion host and EKS worker nodes
- AWS Secrets Manager secrets as an external source of secrets for the FileFlux application, integrated with Kubernetes to provide secrets to the various microservices
- AWS Certificate Manager (ACM) and Cloudflare for automatic validation, issuance and renewal of SSL certificates for the FileFlux application
- ExternalDNS integrated with Cloudflare for automatic creation and deletion of DNS records in Cloudflare for the FileFlux application
- Prometheus with custom Grafana dashboards for monitoring and alerting on the EKS cluster, worker nodes, ZFS pools, and the FileFlux application
- Fluent Bit for log collection and forwarding to Cloudwatch and ELK stack (Elasticsearch, Logstash, Kibana) for log storage, processing, and visualization
- ArgoCD for GitOps-based continuous delivery and deployment of Helm charts and Kubernetes manifests
- Istio for service mesh, traffic management and blue-green deployments
- Fargate for serverless container orchestration to deploy Karpenter for provisioning and autoscaling of EKS worker nodes
- Karpenter for provisioning and autoscaling of EKS worker nodes based on EC2 Spot and On-Demand instances
- Packer for building custom AMIs based on Ubuntu 22.04 with ZFS filesystem and other necessary configurations
- KMS for encryption of sensitive data in EBS volumes 
- Kubernetes namespaces, priority classes, manifess, and other resources for organizing and managing the various microservices that make up the FileFlux application

## Setup and Deployment

To deploy the FileFlux infrastructure using Terraform, follow these steps:

1. Clone this repository to your local machine.
2. Ensure that you have Terraform installed and the AWS CLI configured with the necessary credentials.
3. Review and modify the `variables.tf` file if needed, such as updating the AWS region, instance type, etc.
4. Run the `terraform init` following command to initialize Terraform.
5. Run the `terraform plan` command to preview the changes that Terraform will make.
6. If the plan looks good, run the `terraform apply` command to apply the changes and create the infrastructure.
7. Terraform will create the specified resources in your AWS account. Once the deployment is complete, you can access the FlieFlux application using the domain name entered while running the Terraform apply command.

## Destroying the Infrastructure

To destroy the Jenkins infrastructure and clean up the resources, run the `terraform destroy` command

Terraform will prompt you to confirm the destruction of the resources. Enter `yes` to proceed.

## GitHub Actions Workflow

A GitHub Actions workflow is included to automate the Terraform configuration validation process. 

This workflow:
1. Checks the code and sets up Terraform.
2. Runs `terraform init` to initialize the Terraform configuration.
3. Runs `terraform fmt` to format the Terraform configuration files.
4. Runs `terraform validate` to validate the Terraform configuration.

## Multiple Environments
In order to deploy this infrastructure in multiple environments without duplicating the code and while maintaining distinct Terraform state files, I'd recommend using Terraform Workspaces
1. **Create a new workspace:**
   ```bash
   terraform workspace new workspacenew
2. **Switch to the new workspace:**
   ```bash
   terraform workspace select workspacenew 
3. **List workspaces:**
   ```bash
   terraform workspace list 
4. **Delete a workspace:**
   ```bash
   terraform workspace select default 
   terraform workspace delete workspacenew 

## Notes
- Ensure you have necessary permissions in your AWS account to create these resources.
- The EKS cluster and its components will incur costs in your AWS account. Ensure you understand the costs associated with running an EKS cluster and its components.
- Always review the Terraform plan before applying to understand the changes that will be made to your infrastructure.
- This code includes Karperter for provisioning and autoscaling of EKS worker nodes based on EC2 Spot and On-Demand instances. Ensure you understand the costs associated with using EC2 Spot instances and the implications of using them in your production environment.