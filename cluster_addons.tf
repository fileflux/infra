resource "aws_eks_addon" "ebs" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi.arn
  depends_on               = [time_sleep.wait_for_ebs]
}

resource "aws_eks_addon" "eks-pod-identity-agent" {
  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"
  depends_on   = [aws_eks_addon.vpc-cni]
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name = var.cluster_name
  addon_name   = "kube-proxy"
  depends_on   = [aws_eks_addon.eks-pod-identity-agent]
}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name             = var.cluster_name
  addon_name               = "vpc-cni"
  service_account_role_arn = aws_iam_role.vpc_cni.arn
  depends_on               = [time_sleep.wait_for_nodepool]
}

resource "time_sleep" "wait_for_ebs" {
  depends_on      = [aws_eks_addon.kube-proxy]
  create_duration = "30s"
}

resource "helm_release" "csi_secrets_store" {
  name       = "csi-secrets-store"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.4.5"

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }

  set {
    name  = "priorityClassName"
    value = kubernetes_priority_class.daemonset-priority.metadata[0].name
  }

  depends_on = [kubernetes_priority_class.daemonset-priority]
}

resource "helm_release" "secrets_store_csi_driver_provider_aws" {
  name       = "secrets-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.9"
  depends_on = [helm_release.csi_secrets_store]
}