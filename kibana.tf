resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "kibana"
  version    = "11.2.18"
  namespace  = kubernetes_namespace.logging.metadata[0].name
  values = [
    file("kibana.yaml")
  ]
  depends_on = [helm_release.elasticsearch]
}
