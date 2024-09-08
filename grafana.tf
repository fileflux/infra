resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  depends_on = [
    data.local_file.custom_dashboard1,
    data.local_file.custom_dashboard2,
    data.local_file.custom_dashboard3,
    kubernetes_namespace.monitoring
  ]

  values = [
    jsonencode({
      rbac = {
        create     = true
        namespaced = false
        extraClusterRoleRules = [
          {
            apiGroups = [""]
            resources = ["configmaps", "secrets", "pods", "services", "endpoints"]
            verbs     = ["get", "list", "watch"]
          },
          {
            apiGroups = ["extensions", "apps"]
            resources = ["deployments"]
            verbs     = ["get", "list", "watch"]
          }
        ]
      }

      serviceAccount = {
        create                       = true
        name                         = "grafana"
        automountServiceAccountToken = true
      }

      adminUser     = "admin"
      adminPassword = "admin"

      service = {
        type = "LoadBalancer"
        annotations = {
          "external-dns.alpha.kubernetes.io/hostname"                     = "dashboard.lokesh.cloud"
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "http"
          "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"        = "443"
          "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol"   = "*"
          "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"         = aws_acm_certificate.grafana_cert.arn
        }
        ports = [
          {
            name       = "http"
            port       = 80
            targetPort = 3000
            protocol   = "TCP"
          },
          {
            name       = "https"
            port       = 443
            targetPort = 3000
            protocol   = "TCP"
          }
        ]
      }

      extraExposePorts = [
        {
          name       = "https"
          port       = 443
          targetPort = 3000
        }
      ]

      persistence = {
        enabled          = true
        storageClassName = "gp2"
        accessModes      = ["ReadWriteOnce"]
        size             = "10Gi"
      }

      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-server.monitoring.svc.cluster.local"
              access    = "proxy"
              isDefault = true
              uid       = "prometheus"
            }
          ]
        }
      }

      dashboardProviders = {
        "dashboardproviders.yaml" = {
          apiVersion = 1
          providers = [
            {
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }
          ]
        }
      }

      dashboards = {
        default = {
          custom_dashboard1 = {
            json = data.local_file.custom_dashboard1.content
          }
          custom_dashboard2 = {
            json = data.local_file.custom_dashboard2.content
          }
          custom_dashboard3 = {
            json = data.local_file.custom_dashboard3.content
          }
        }
      }
    })
  ]
}

data "local_file" "custom_dashboard1" {
  filename = "grafana_dashboards/k8s.json"
}

data "local_file" "custom_dashboard2" {
  filename = "grafana_dashboards/s3.json"
}

data "local_file" "custom_dashboard3" {
  filename = "grafana_dashboards/zfs.json"
}
