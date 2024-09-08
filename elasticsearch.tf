resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "elasticsearch"
  version    = "21.3.10"
  namespace  = kubernetes_namespace.logging.metadata[0].name
  values = [
    file("elasticsearch.yaml")
  ]
  depends_on = [kubernetes_namespace.logging]
}