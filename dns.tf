resource "kubernetes_secret" "cloudflare_api_key" {
  metadata {
    name      = "cloudflare-api-key"
    namespace = "kube-system"
  }

  data = {
    apiKey = var.cloudflare_api_key
    email  = var.cloudflare_email
  }

  type       = "Opaque"
  depends_on = [null_resource.dependency, data.local_file.kubeconfig]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"

  set {
    name  = "provider.name"
    value = "cloudflare"
  }

  set {
    name  = "env[0].name"
    value = "CF_API_KEY"
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.name"
    value = "cloudflare-api-key"
  }

  set {
    name  = "env[0].valueFrom.secretKeyRef.key"
    value = "apiKey"
  }

  set {
    name  = "env[1].name"
    value = "CF_API_EMAIL"
  }

  set {
    name  = "env[1].valueFrom.secretKeyRef.name"
    value = "cloudflare-api-key"
  }

  set {
    name  = "env[1].valueFrom.secretKeyRef.key"
    value = "email"
  }

  set {
    name  = "domainFilters[0]"
    value = "lokesh.cloud"
  }

  set {
    name  = "txtOwnerId"
    value = "external-dns"
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  depends_on = [
    kubernetes_secret.cloudflare_api_key, kubectl_manifest.karpenter_node_pool, aws_eks_addon.ebs
  ]
}
