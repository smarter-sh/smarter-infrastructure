# Helm values for metrics-server (chart https://kubernetes-sigs.github.io/metrics-server/).
#
# metrics-server serves the resource metrics API (metrics.k8s.io): the CPU and
# memory use of every pod and node, scraped from each kubelet every 15 seconds.
# HorizontalPodAutoscalers that scale on cpu or memory utilization read it, as
# do kubectl top and the descheduler's utilization strategies. Without it, an
# HPA reports FailedGetResourceMetric and never scales above minReplicas.

# pulled through the ECR pull-through cache for registry.k8s.io
image:
  repository: ${image_repository}

# Two replicas on different nodes, so that a spot interruption or a node group
# replacement doesn't leave every HPA in the cluster blind. The pod disruption
# budget keeps one running while a node is drained.
replicas: 2

podDisruptionBudget:
  enabled: true
  minAvailable: 1

topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app.kubernetes.io/name: metrics-server
        app.kubernetes.io/instance: metrics-server
