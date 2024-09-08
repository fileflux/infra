resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  depends_on = [kubernetes_namespace.monitoring]
  values = [
    file("prometheus.yaml")
  ]
}