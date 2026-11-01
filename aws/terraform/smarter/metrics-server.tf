#------------------------------------------------------------------------------
# metrics-server: the resource metrics API (metrics.k8s.io)
#
# The smarter Helm chart's HorizontalPodAutoscalers (hpa-app.yaml,
# hpa-worker.yaml) scale on cpu and memory utilization, which they read from
# this API. EKS doesn't install it, and without it every HPA reports
# FailedGetResourceMetric and never scales above minReplicas.
#
# One per cluster. metrics-server registers the cluster-wide APIService
# v1beta1.metrics.k8s.io and cluster roles, and every environment on the
# cluster reads from it. So exactly one environment installs it: the one whose
# terragrunt.hcl sets install_metrics_server = true (prod). A second install
# would fail on Helm ownership of those cluster-scoped objects.
#
# Network: it runs in kube-system, which no network policy covers. The EKS
# control plane reaches it, and it reaches each kubelet on TCP 10250, through
# the node security group's ingress from the VPC CIDR
# (../kubernetes/main.tf).
#
# The chart is pinned so that a rebuilt cluster gets the same version; upgrade
# it deliberately.
#------------------------------------------------------------------------------
resource "helm_release" "metrics_server" {
  count = var.install_metrics_server ? 1 : 0

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.14.0"
  namespace  = "kube-system"

  values = [
    templatefile("${path.module}/templates/metrics-server.yaml.tpl", {
      # registry.k8s.io, through the ECR pull-through cache (k8s prefix) that
      # the kubernetes stack creates
      image_repository = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/k8s/metrics-server/metrics-server"
    })
  ]
}
