resource "kubernetes_priority_class" "daemonset-priority" {
  metadata {
    name = "daemonset-priority"
  }
  value          = 1000000
  global_default = false
  description    = "Priority class for the high-priority DaemonSet"
  depends_on     = [aws_eks_addon.ebs]
}