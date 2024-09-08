resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = kubernetes_namespace.istio.metadata[0].name
  depends_on = [kubernetes_namespace.istio]
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = kubernetes_namespace.istio.metadata[0].name
  values     = [file("./istio.yaml")]
  depends_on = [kubernetes_namespace.istio, helm_release.istio_base]
}

resource "helm_release" "istio_ingress" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  namespace  = kubernetes_namespace.istio_gw.metadata[0].name
  depends_on = [kubernetes_namespace.istio_gw, helm_release.istiod]
  values = [
    yamlencode({
      gateways = {
        istio-ingressgateway = {
          type = "LoadBalancer"
        }
      }
    })
  ]
}
