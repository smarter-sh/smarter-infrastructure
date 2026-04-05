#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Mar-2026
#
# usage: setup Kubernetes network policies for smarter application group.
# This file provisions Calico as the CNI provider and sets up a set of Kubernetes
# network policies to tightly control pod-to-pod communication within the cluster.
# The policies accomplish the following:
# - Restrict access to MariaDB and Redis pods, allowing only authorized backend pods
#   (identified by specific labels) to connect on their respective ports.
# - Enforce a default-deny ingress policy for MariaDB, Redis, and the application group
#   in the production namespace, blocking all traffic except what is explicitly allowed.
# - Limit egress from application group pods to only the required database ports and
#   destinations, reducing the risk of lateral movement or data exfiltration.
#   These policies provide fine-grained, dynamic, and label-based network segmentation
#   at the pod level, which cannot be achieved with cloud provider security groups alone.
#   They help ensure that only intended services can communicate, improving the security
#   posture of the Smarter platform.
#------------------------------------------------------------------------------

locals {
  db_port = 3306
  cache_port = 6379
}
data "aws_vpc" "smarter_vpc" {
  id = var.vpc_id
}

resource "helm_release" "calico" {
  name       = "calico"
  repository = "https://docs.tigera.io/calico/charts"
  chart      = "tigera-operator"
  namespace  = "tigera-operator"
  create_namespace = true

  values = [
    yamlencode({
      installation = {
        calicoNetwork = {
          bgp = "Disabled"
          ipPools = [
            {
              blockSize = 26
              cidr      = data.aws_vpc.smarter_vpc.cidr_block
              encapsulation = "VXLANCrossSubnet"
              natOutgoing   = "Enabled"
              nodeSelector  = "all()"
            }
          ]
        }
      }
    })
  ]
}


resource "kubernetes_network_policy_v1" "smarter_mariadb_allow_backend" {
  metadata {
    name      = "mariadb-allow-backend"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "mariadb"
        "app.kubernetes.io/instance" = var.platform_name
      }
    }

    policy_types = ["Ingress"]

  ingress {
    from {
      pod_selector {
        match_labels = {
          "app.kubernetes.io/application-group" = var.platform_name
        }
      }
    }
    ports {
      protocol = "TCP"
      port     = local.db_port
    }
  }

  }
}

resource "kubernetes_network_policy_v1" "smarter_redis_allow_backend" {
  metadata {
    name      = "redis-allow-backend"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"     = "redis"
        "app.kubernetes.io/instance" = var.platform_name
        "app.kubernetes.io/component" = "master"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/application-group" = var.platform_name
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = local.cache_port
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "smarter_default_deny_mariadb" {
  metadata {
    name      = "default-deny-mariadb"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "mariadb"
        "app.kubernetes.io/instance" = var.platform_name
      }
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "smarter_default_deny_redis" {
  metadata {
    name      = "default-deny-redis"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "redis"
        "app.kubernetes.io/instance" = var.platform_name
        "app.kubernetes.io/component" = "master"
      }
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "smarter_default_deny_smarter_application_group" {
  metadata {
    name      = "default-deny-smarter-application-group"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/application-group" = var.platform_name
      }
    }
    policy_types = ["Ingress"]
  }
}

# Allow egress from MariaDB pods to application group pods on TCP port 3306
resource "kubernetes_network_policy_v1" "mariadb_egress" {
  metadata {
    name      = "mariadb-egress"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"     = "mariadb"
        "app.kubernetes.io/instance" = var.platform_name
      }
    }
    policy_types = ["Egress"]
    egress {
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/application-group" = var.platform_name
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = local.db_port
      }
    }
  }
}

# Allow egress from Redis pods to application group pods on TCP port 6379
resource "kubernetes_network_policy_v1" "redis_egress" {
  metadata {
    name      = "redis-egress"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"      = "redis"
        "app.kubernetes.io/instance"  = var.platform_name
        "app.kubernetes.io/component" = "master"
      }
    }
    policy_types = ["Egress"]
    egress {
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/application-group" = var.platform_name
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = local.cache_port
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "smarter_application_group_egress" {
  metadata {
    name      = "smarter-application-group-egress"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/application-group" = var.platform_name
      }
    }

    policy_types = ["Egress"]


    # Allow egress to any destination on TCP port 8000 (out of the VPC)
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = 8000
      }
    }

  }
}
