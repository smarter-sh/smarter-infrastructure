autoDiscovery:
  clusterName: ${cluster_name}

awsRegion: ${region}

rbac:
  serviceAccount:
    create: true
    name: cluster-autoscaler
    annotations:
      eks.amazonaws.com/role-arn: ${autoscaler_role_arn}

extraArgs:
  balance-similar-node-groups: true
  skip-nodes-with-local-storage: false
  skip-nodes-with-system-pods: false

# pulled through the ECR pull-through cache for registry.k8s.io
image:
  repository: ${image_repository}
