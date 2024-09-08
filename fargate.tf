resource "aws_eks_fargate_profile" "karpenter" {
  cluster_name           = module.eks.cluster_name
  fargate_profile_name   = "karpenter"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = aws_subnet.private_subnets[*].id

  selector {
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/instance" = "karpenter"
    }
  }
  depends_on = [aws_route_table_association.private_subnet, module.eks]
}

resource "aws_iam_role" "fargate" {
  name = "eks-fargate"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "fargate" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate.name
}

resource "null_resource" "delete_fargate_profile" {
  provisioner "local-exec" {
    command = <<EOT
      aws eks delete-fargate-profile \
        --cluster-name ${var.cluster_name} \
        --region ${var.region} \
        --fargate-profile-name ${aws_eks_fargate_profile.karpenter.fargate_profile_name}
    EOT
  }

  depends_on = [aws_eks_addon.ebs]
}