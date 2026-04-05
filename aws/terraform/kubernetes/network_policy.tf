###############################################################################
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
###############################################################################

locals {
  db_port = 3306      # Default port for MariaDB
  cache_port = 6379   # Default port for Redis
}

data "aws_vpc" "smarter_vpc" {
  id = var.vpc_id
}

#------------------------------------------------------------------------------
# Calico is an open-source networking and network security solution for
# containers, virtual machines, and native host-based workloads. In Kubernetes,
# Calico provides a highly scalable networking backend and implements Kubernetes
# NetworkPolicy for fine-grained, label-based security controls between pods.
#
# Key features:
# - Implements Kubernetes CNI (Container Network Interface) for pod networking
# - Enforces network policies for traffic control and microsegmentation
# - Supports both layer 3 (routing) and layer 2 (bridging) networking
# - Provides network security, isolation, and visibility
# - Can be used with or without BGP, and supports multiple cloud and on-prem
# environments
#
# In this configuration, Calico is deployed as the CNI provider to enable
# advanced network policy enforcement and secure pod-to-pod communication within
# the Kubernetes cluster.
#------------------------------------------------------------------------------
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


# ------------------------------------------------------------------------------
# Allows TCP ingress on port 8000 to application group pods.
#
# This network policy permits incoming TCP traffic from any source (0.0.0.0/0)
# to all pods labeled with app.kubernetes.io/application-group = var.platform_name
# on port 8000. Use this to expose services (such as HTTP APIs) running on port 8000
# within the application group to external or internal clients.
# ------------------------------------------------------------------------------
resource "kubernetes_network_policy_v1" "smarter_application_group_ingress_8000" {
  metadata {
    name      = "smarter-application-group-ingress-8000"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/application-group" = var.platform_name
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
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

#------------------------------------------------------------------------------
# This network policy allows only authorized pods to initiate TCP connections
# to MariaDB pods on the database port (default 3306). All other ingress
# traffic to MariaDB pods is denied by default via the default-deny
# policy (see below).
#
# This ensures that only application group pods can access the MariaDB service,
# improving security by preventing unauthorized pods from connecting to
# the database.
#------------------------------------------------------------------------------
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

#------------------------------------------------------------------------------
# This network policy allows only authorized pods to initiate TCP connections
# to Redis pods on the cache port (default 6379). All other ingress traffic
# to Redis pods is denied by default (assuming a default-deny policy is also in place).
#
# This ensures that only application group pods can access the Redis service,
# improving security by preventing unauthorized pods from connecting to the cache.
#------------------------------------------------------------------------------
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

#------------------------------------------------------------------------------
# This network policy enforces a default-deny ingress rule for MariaDB pods.
# It blocks all incoming traffic to these pods unless explicitly allowed by another
# network policy.
#
# This is a security best practice, ensuring that only traffic matching specific
# allow rules (such as from authorized application group pods) can reach MariaDB,
# and all other ingress is denied by default.
#------------------------------------------------------------------------------
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

#------------------------------------------------------------------------------
# This network policy enforces a default-deny ingress rule for all pods in the
# application group. It blocks all incoming traffic to these pods unless
# explicitly allowed by another network policy.
#
# This is a security best practice, ensuring that only traffic matching specific
# allow rules can reach application group pods, and all other ingress is denied by default.
#------------------------------------------------------------------------------
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

#------------------------------------------------------------------------------
# NOTE: For normal SQL query/response, you do NOT need an egress policy on MariaDB
# to allow results to be sent back to application pods. Responses flow over the
# established connection initiated by the application pod, and are allowed by default.
#
# This egress policy is only needed if MariaDB pods must initiate NEW outbound TCP
# connections to application group pods on port 3306 (for example, for replication,
# notifications, or callbacks). If you do not require MariaDB to initiate such
# connections, you can safely remove this policy.
#------------------------------------------------------------------------------
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

#------------------------------------------------------------------------------
# NOTE: For normal Redis request/response, you do NOT need an egress policy on Redis
# to allow responses to be sent back to application pods. Responses flow over the
# established connection initiated by the application pod, and are allowed by default.
#
# This egress policy is only needed if Redis pods must initiate NEW outbound TCP
# connections to application group pods on port 6379 (for example, for notifications,
# pub/sub, or callbacks). If you do not require Redis to initiate such connections,
# you can safely remove this policy.
#------------------------------------------------------------------------------
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

#------------------------------------------------------------------------------
# This network policy allows pods in the application group to send TCP traffic
# to any destination on port 8000 (for example, to external services or APIs).
#
# This is useful when application pods need to make outbound connections on port 8000,
# such as for HTTP APIs, webhooks, or other services outside the cluster or VPC.
# All other egress traffic is denied by default unless explicitly allowed by
# another policy.
#------------------------------------------------------------------------------
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
