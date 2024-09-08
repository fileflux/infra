resource "kubernetes_namespace" "s3" {
  metadata {
    labels = {
      namespace       = "s3"
      istio-injection = "enabled"
    }

    name = "s3"
  }
  depends_on = [null_resource.dependency, aws_eks_addon.ebs]
}

resource "kubernetes_namespace" "lifecycle" {
  metadata {
    labels = {
      namespace       = "lifecycle"
      istio-injection = "disabled"
    }

    name = "lifecycle"
  }
  depends_on = [null_resource.dependency, aws_eks_addon.ebs]
}

resource "kubernetes_namespace" "crdb" {
  metadata {
    labels = {
      namespace       = "crdb"
      istio-injection = "disabled"
    }

    name = "crdb"
  }
  depends_on = [null_resource.dependency, aws_eks_addon.ebs]
}

resource "kubernetes_namespace" "istio" {
  metadata {
    labels = {
      namespace       = "istio"
      istio-injection = "enabled"
    }

    name = "istio-system"
  }
  depends_on = [null_resource.dependency, helm_release.secrets_store_csi_driver_provider_aws]
}

resource "kubernetes_namespace" "istio_gw" {
  metadata {
    labels = {
      namespace       = "istio-ingress"
      istio-injection = "enabled"
    }

    name = "istio-ingress"
  }
  depends_on = [null_resource.dependency, helm_release.secrets_store_csi_driver_provider_aws]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    labels = {
      namespace       = "monitoring"
      istio-injection = "disabled"
    }

    name = "monitoring"
  }
  depends_on = [null_resource.dependency, aws_eks_addon.ebs]
}

resource "kubernetes_namespace" "logging" {
  metadata {
    labels = {
      namespace       = "logging"
      istio-injection = "disabled"
    }

    name = "logging"
  }
  depends_on = [null_resource.dependency, helm_release.grafana]
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    labels = {
      namespace       = "argocd"
      istio-injection = "disabled"
    }

    name = "argocd"
  }
  depends_on = [null_resource.dependency, helm_release.logstash]
}

