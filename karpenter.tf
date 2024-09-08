data "aws_availability_zones" "available" {}
data "aws_partition" "current" {}

locals {
  account_id           = data.aws_caller_identity.current.account_id
  partition            = data.aws_partition.current.partition
  region               = var.region
  queue_name           = "karpenter"
  create_node_iam_role = false
  node_iam_role_name   = aws_iam_role.karpenter_node_role.name
  oidc_provider        = module.eks.oidc_provider
  oidc_provider_arn    = module.eks.oidc_provider_arn
}

resource "aws_iam_role" "controller" {
  name                  = "KarpenterController"
  assume_role_policy    = data.aws_iam_policy_document.controller_assume_role.json
  force_detach_policies = true

}

data "aws_iam_policy_document" "controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

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
      values   = ["system:serviceaccount:kube-system:karpenterirsa"]
    }
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

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
      values   = ["system:serviceaccount:s3:db-access"]
    }
  }
}

data "aws_iam_policy_document" "controller" {

  statement {
    sid = "AllowScopedEC2InstanceActions"
    resources = [
      "*"
    ]

    actions = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "controller" {

  name   = "KarpenterController"
  policy = data.aws_iam_policy_document.controller.json

}

resource "aws_iam_role_policy_attachment" "controller" {


  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.11"

  cluster_name = module.eks.cluster_name

  enable_v1_permissions           = true
  create_iam_role                 = false
  enable_pod_identity             = true
  create_pod_identity_association = true

  tags       = var.cluster_tags
  depends_on = [module.eks, null_resource.dependency, data.local_file.kubeconfig, aws_eks_fargate_profile.karpenter]
}

resource "helm_release" "karpenter" {
  namespace  = "kube-system"
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.0.1"
  wait       = true

  values = [
    <<-EOT
    serviceAccount:
      create: true
      name: karpenterirsa
      annotations:
        eks.amazonaws.com/role-arn: ${aws_iam_role.controller.arn}
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
    dnsPolicy: Default
    controller:
      resources:
        requests:
          cpu: 1
          memory: 1Gi
    tolerations:
      - key: eks.amazonaws.com/compute-type
        operator: Equal
        value: fargate
        effect: NoSchedule
    topologySpreadConstraints: []
    affinity: null
    nodeSelector: null
    EOT
  ]
  depends_on = [module.karpenter]
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [helm_release.karpenter]

  create_duration = "30s"
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: Ubuntu
      amiSelectorTerms:
        - id: ${data.local_file.ami_id.content}
      metadataOptions:
        httpEndpoint: enabled
        httpProtocolIPv6: disabled
        httpPutResponseHopLimit: 2 
        httpTokens: required
      role: ${aws_iam_role.karpenter_node_role.name}
      blockDeviceMappings:
        - deviceName: /dev/sda1
          rootVolume: true
          ebs:
            volumeSize: 20Gi
            volumeType: gp2
            encrypted: true
            deleteOnTermination: true
        - deviceName: /dev/sda2
          ebs:
            volumeSize: 20Gi
            volumeType: gp2
            encrypted: true
            deleteOnTermination: true
      associatePublicIPAddress: false
      detailedMonitoring: true  
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
            environment: dev
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
      tags:
        karpenter.sh/discovery: ${var.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter, time_sleep.wait_30_seconds
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: app
              operator: Exists
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c"]
            - key: "karpenter.k8s.aws/instance-memory"
              operator: In
              values: ["8192"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["spot", "on-demand"]
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

resource "time_sleep" "wait_for_nodepool" {
  depends_on      = [kubectl_manifest.karpenter_node_pool]
  create_duration = "60s"
}

data "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
  depends_on = [data.local_file.kubeconfig, null_resource.dependency, aws_eks_fargate_profile.karpenter]
}

locals {
  aws_auth_data = yamldecode(data.kubernetes_config_map.aws_auth.data.mapRoles)
  new_role_mapping = [
    {
      rolearn  = aws_iam_role.karpenter_node_role.arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    }
  ]
  merged_role_mappings = distinct(concat(local.aws_auth_data, local.new_role_mapping))
  depends_on           = [aws_eks_fargate_profile.karpenter]
}

resource "kubernetes_config_map_v1_data" "aws_auth_patch" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(local.merged_role_mappings)
  }

  force      = true
  depends_on = [local.aws_auth_data]
}