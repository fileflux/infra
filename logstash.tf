resource "helm_release" "logstash" {
  name       = "logstash"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "logstash"
  version    = "6.3.2"
  namespace  = kubernetes_namespace.logging.metadata[0].name
  values = [
    file("logstash.yaml")
  ]
  depends_on = [helm_release.elasticsearch]
}
