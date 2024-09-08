resource "kubernetes_daemonset" "fluentbit" {
  metadata {
    name      = "fluentbit"
    namespace = "kube-system"
    labels = {
      k8s-app = "fluentbit"
    }
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "fluentbit"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app = "fluentbit"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.fluentbit.metadata[0].name
        container {
          name  = "fluentbit"
          image = "amazon/aws-for-fluent-bit:2.31.11"

          resources {
            limits = {
              memory = "200Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "100Mi"
            }
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
          }

          volume_mount {
            name       = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }

          volume_mount {
            name       = "fluent-bit-config"
            mount_path = "/fluent-bit/etc/"
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }

        volume {
          name = "fluent-bit-config"
          config_map {
            name = kubernetes_config_map.fluentbit_config.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_account" "fluentbit" {
  metadata {
    name      = "fluentbit"
    namespace = "kube-system"
  }
  depends_on = [helm_release.grafana]
}

resource "kubernetes_cluster_role" "fluentbit" {
  metadata {
    name = "fluentbit"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "fluentbit" {
  metadata {
    name = "fluentbit"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluentbit.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluentbit.metadata[0].name
    namespace = "kube-system"
  }
}

resource "kubernetes_config_map" "fluentbit_config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = "kube-system"
    labels = {
      k8s-app = "fluentbit"
    }
  }

  data = {
    "fluent-bit.conf" = <<EOF
[SERVICE]
    Flush         1
    Log_Level     info
    Daemon        off
    Parsers_File  parsers.conf
    HTTP_Server   On
    HTTP_Listen   0.0.0.0
    HTTP_Port     2020

[INPUT]
    Name              tail
    Tag               kube.*
    Path              /var/log/containers/*.log
    Parser            docker
    DB                /var/log/flb_kube.db
    Mem_Buf_Limit     5MB
    Skip_Long_Lines   On
    Refresh_Interval  10

[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443
    Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    Kube_Tag_Prefix     kube.var.log.containers.
    Merge_Log           On
    Merge_Log_Key       log_processed
    K8S-Logging.Parser  On
    K8S-Logging.Exclude Off

[OUTPUT]
    Name              cloudwatch
    Match             *
    region            ${var.region}
    log_group_name    /aws/eks/${var.cluster_name}/logs
    log_stream_prefix from-fluent-bit-
    auto_create_group true

[OUTPUT]
    Name              http
    Match             *
    Host              logstash.logging.svc.cluster.local
    Port              8080
    URI               /
    Format            json
    Retry_Limit       False
EOF

    "parsers.conf" = <<EOF
[PARSER]
    Name   docker
    Format json
    Time_Key time
    Time_Format %Y-%m-%dT%H:%M:%S.%LZ
EOF
  }
}