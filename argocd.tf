resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
  depends_on = [kubernetes_namespace.argocd]
}

locals {
  s3 = {
    s3manager = {
      name      = "s3manager"
      repo_url  = "https://github.com/lokesh1306/helm-s3manager"
      path      = "."
      namespace = "s3"
    },
    s3worker = {
      name      = "s3worker"
      repo_url  = "https://github.com/lokesh1306/helm-s3worker"
      path      = "."
      namespace = "s3"
    }
  }
}

resource "kubectl_manifest" "crdb" {

  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cockroachdb
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/lokesh1306/helm-cockroachdb
    targetRevision: main
    path: .
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: crdb
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

  depends_on = [helm_release.argocd]
}

resource "time_sleep" "wait_60_seconds" {
  depends_on      = [kubectl_manifest.crdb]
  create_duration = "60s"
}

resource "kubectl_manifest" "s3" {
  for_each = local.s3

  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${each.value.name}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${each.value.repo_url}
    targetRevision: main
    path: ${each.value.path}
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: ${each.value.namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

  depends_on = [time_sleep.wait_60_seconds]
}

resource "kubectl_manifest" "istio" {

  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bluegreen
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/lokesh1306/istio_bluegreen
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: s3
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
YAML

  depends_on = [kubectl_manifest.s3]
}