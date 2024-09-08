module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.14.0"

  cluster_name                    = var.cluster_name
  cluster_version                 = var.k8_cluster_version
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  create_iam_role                 = false
  create_kms_key                  = false
  create_cluster_security_group   = false
  cluster_enabled_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  enable_irsa                     = true

  cluster_addons                           = {}
  vpc_id                                   = aws_vpc.main.id
  enable_cluster_creator_admin_permissions = true
  subnet_ids                               = aws_subnet.public_subnets[*].id
  control_plane_subnet_ids                 = aws_subnet.public_subnets[*].id
  cluster_security_group_id                = aws_security_group.cluster.id
  iam_role_arn                             = aws_iam_role.cluster_role.arn
  authentication_mode                      = var.authentication_mode
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks.arn
  }
  cluster_ip_family = var.family
  node_security_group_tags = merge(var.cluster_tags, {
    "karpenter.sh/discovery" = var.cluster_name
  })
  tags = merge(
    var.cluster_tags
  )
  depends_on = [null_resource.packer]
}

resource "null_resource" "kubeconfig" {
  depends_on = [module.eks]

  provisioner "local-exec" {
    command = "aws eks get-token --cluster-name ${var.cluster_name} --region ${var.region} && aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region}"
  }
}

data "local_file" "kubeconfig" {
  depends_on = [null_resource.kubeconfig]
  filename   = pathexpand("~/.kube/config")
}

resource "null_resource" "dependency" {
  provisioner "local-exec" {
    command = "sleep 5"
  }
  depends_on = [aws_iam_policy.eks_kms_policy, aws_iam_policy.eks_kms_policy_ebs, aws_iam_role.cluster_role, aws_iam_role.karpenter_node_role, aws_iam_role_policy_attachment.eks_cluster_role_policy_attachment["AmazonEBSCSIDriverPolicy"], aws_iam_role_policy_attachment.eks_cluster_role_policy_attachment["AmazonEKSClusterPolicy"], aws_iam_role_policy_attachment.eks_cluster_role_policy_attachment["AmazonEKSVPCResourceController"], aws_iam_role_policy_attachment.eks_cluster_role_policy_attachment["AmazonEKS_CNI_Policy"], aws_iam_role_policy_attachment.eks_kms_policy_attachment, aws_iam_role_policy_attachment.eks_kms_policy_attachment_ebs, aws_iam_role_policy_attachment.eks_node_role_policy_attachment["AmazonEBSCSIDriverPolicy"], aws_iam_role_policy_attachment.eks_node_role_policy_attachment["AmazonEC2ContainerRegistryReadOnly"], aws_iam_role_policy_attachment.eks_node_role_policy_attachment["AmazonEKSWorkerNodePolicy"], aws_iam_role_policy_attachment.eks_node_role_policy_attachment["AmazonEKS_CNI_Policy"], aws_internet_gateway.gateway, aws_kms_key.ebs, aws_kms_key.eks, aws_route_table.public_subnet_route_table[0], aws_route_table.public_subnet_route_table[1], aws_route_table.public_subnet_route_table[2], aws_route_table_association.public_subnet[0], aws_route_table_association.public_subnet[1], aws_route_table_association.public_subnet[2], aws_security_group.cluster, aws_security_group.node, aws_security_group.node_ssh_sg, aws_security_group_rule.cluster_ingress[0], aws_security_group_rule.node_egress[0], aws_subnet.public_subnets[0], aws_subnet.public_subnets[1], aws_subnet.public_subnets[2], aws_vpc.main, module.eks, aws_iam_role_policy_attachment.controller, aws_acm_certificate_validation.s3_cert, aws_iam_policy.controller, aws_iam_role_policy_attachment.fargate, aws_iam_role_policy_attachment.karpenter_policy_attach, aws_iam_policy.karpenter_node_policy]
}

resource "null_resource" "apply_metrics_server" {
  provisioner "local-exec" {
    command = "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
  }
  depends_on = [null_resource.dependency, data.local_file.kubeconfig, kubernetes_namespace.monitoring]
}
