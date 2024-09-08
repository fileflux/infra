resource "aws_iam_role" "cluster_role" {
  name = "cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy" "cluster_management_group_policy" {
  for_each = toset(["AmazonEKSClusterPolicy", "AmazonEKSVPCResourceController", "AmazonEKS_CNI_Policy", "AmazonEBSCSIDriverPolicy"])
  name     = each.value
}

resource "aws_iam_role_policy_attachment" "eks_cluster_role_policy_attachment" {
  for_each   = data.aws_iam_policy.cluster_management_group_policy
  role       = aws_iam_role.cluster_role.name
  policy_arn = each.value.arn
}

data "aws_iam_policy_document" "eks_kms_policy" {
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey", "kms:CreateGrant"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eks_kms_policy" {
  name   = "eks-kms-policy"
  policy = data.aws_iam_policy_document.eks_kms_policy.json
}

resource "aws_iam_role_policy_attachment" "eks_kms_policy_attachment" {
  role       = aws_iam_role.cluster_role.name
  policy_arn = aws_iam_policy.eks_kms_policy.arn
}

resource "aws_iam_policy" "eks_kms_policy_ebs" {
  name   = "eks-kms-policy_ebs"
  policy = data.aws_iam_policy_document.eks_kms_policy_ebs.json
}

data "aws_iam_policy_document" "eks_kms_policy_ebs" {
  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey", "kms:CreateGrant"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "eks_kms_policy_attachment_ebs" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = aws_iam_policy.eks_kms_policy_ebs.arn
}

data "aws_iam_policy" "node_management_group_policy" {
  for_each = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryReadOnly", "AmazonEKS_CNI_Policy", "AmazonEBSCSIDriverPolicy"])
  name     = each.value
}

resource "aws_iam_role_policy_attachment" "eks_node_role_policy_attachment" {
  for_each   = data.aws_iam_policy.node_management_group_policy
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = each.value.arn
}

data "aws_eks_cluster" "eks" {
  name       = var.cluster_name
  depends_on = [module.eks]
}

data "aws_caller_identity" "infra" {}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = aws_iam_role.karpenter_node_role.name
}

resource "aws_iam_policy" "external_dns_policy" {
  name = "external-dns-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets",
        "route53:ListHostedZones"
      ],
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "external_dns_attachment" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = aws_iam_policy.external_dns_policy.arn
}

resource "aws_iam_role" "karpenter_node_role" {
  name = "KarpenterNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "karpenter_node_policy" {
  name        = "KarpenterNodeRole"
  description = "IAM policy for EKS Cluster Autoscaler"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:*",
          "ec2:*",
          "cloudwatch:*",
          "iam:*",
          "sns:*",
          "elasticloadbalancing:*",
          "pricing:*"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_policy_attach" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = aws_iam_policy.karpenter_node_policy.arn
}

resource "aws_iam_instance_profile" "karpenter_instance_profile" {
  name = "KarpenterNodeInstanceProfile-${var.cluster_name}"
  role = aws_iam_role.karpenter_node_role.name
}

data "aws_iam_policy_document" "ebs_csi_irsa" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_irsa.json
}

resource "aws_iam_role_policy_attachment" "AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

data "aws_iam_policy_document" "vpc_cni_irsa" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:aws-node"]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "vpc_cni" {
  name               = "vpc-cni"
  assume_role_policy = data.aws_iam_policy_document.vpc_cni_irsa.json
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCCNIPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}