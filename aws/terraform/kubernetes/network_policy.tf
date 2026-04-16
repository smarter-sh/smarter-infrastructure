###############################################################################
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Mar-2026
#
# usage: setup Kubernetes network policies for smarter application group.
# This file provisions Calico as the CNI provider and sets up a set of Kubernetes
# network policies to tightly control pod-to-pod communication within the cluster.
# A collection of kubernetes_network_policy_v1 resources are defined that
# dictate the kinds of traffic that can both enter and leave the various kinds
# of pods within the application group.
#
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
  db_port    = 3306 # Default port for MariaDB
  cache_port = 6379 # Default port for Redis
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
  count            = var.enable_enhanced_security ? 1 : 0
  name             = "calico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  namespace        = "tigera-operator"
  create_namespace = true

  values = [
    yamlencode({
      installation = {
        calicoNetwork = {
          bgp = "Disabled"

          encapsulation = "VXLANCrossSubnet"

          ipPools = [
            {
              blockSize    = 26
              cidr         = data.aws_vpc.smarter_vpc.cidr_block
              natOutgoing  = "Enabled"
              nodeSelector = "all()"
            }
          ]
        }
      }
    })
  ]
}


# ------------------------------------------------------------------------------
# Cluster-wide default-deny network policy for all pods in the namespace.
# It applies to every pod in the namespace. This means that, by default,
# no traffic is allowed to flow into or out of any pod
# unless another network policy explicitly permits it.
# ------------------------------------------------------------------------------
resource "kubernetes_network_policy_v1" "default_deny_all" {
  count = var.enable_enhanced_security ? 1 : 0
  metadata {
    name      = "default-deny-all"
    namespace = var.namespace
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
  }
}


# ------------------------------------------------------------------------------
# Network policy to allow all ingress traffic to application group pods from
# any pod in the same namespace. This is necessary to enable communication
# between worker pods and other components within the namespace, while still
# restricting ingress from outside the namespace. The policy selects pods by
# the application-group label and permits all ingress from any namespace peer.
# This is often required for proper operation of distributed workloads,
# background jobs, or horizontally scaled services that need to communicate
# with each other. All other ingress is still denied by the default-deny policy.
# ------------------------------------------------------------------------------
resource "kubernetes_network_policy_v1" "smarter_application_group_ingress" {
  count = var.enable_enhanced_security ? 1 : 0

  metadata {
    name      = "smarter-application-group-ingress"
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
      # allow ALL traffic from same namespace (this fixes workers)
      from {
        namespace_selector {}
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
  count = var.enable_enhanced_security ? 1 : 0

  metadata {
    name      = "mariadb-allow-backend"
    namespace = var.namespace
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"     = "mariadb"
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
  count = var.enable_enhanced_security ? 1 : 0
  metadata {
    name      = "redis-allow-backend"
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
  count = var.enable_enhanced_security ? 1 : 0
  metadata {
    name      = "default-deny-mariadb"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name"     = "mariadb"
        "app.kubernetes.io/instance" = var.platform_name
      }
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy_v1" "smarter_default_deny_redis" {
  count = var.enable_enhanced_security ? 1 : 0

  metadata {
    name      = "default-deny-redis"
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
  count = var.enable_enhanced_security ? 1 : 0
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
  count = var.enable_enhanced_security ? 1 : 0
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
  count = var.enable_enhanced_security ? 1 : 0
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

# ------------------------------------------------------------------------------
# Network policy to allow egress from application group pods to specific
# destinations and ports required for normal operation. All other egress is
# denied by default. This policy enables:
#   - MariaDB: Allow TCP 3306 to MariaDB pods in the same namespace
#   - Redis: Allow TCP 6379 to Redis pods in the same namespace
#   - DNS: Allow UDP/TCP 53 to kube-system namespace (DNS resolution)
#   - External MySQL: Allow TCP 3306 to any external IP (remote DBs)
#
# Each egress rule is narrowly scoped to minimize risk and restrict outbound
# connections to only what is necessary for the application group to function.
# ------------------------------------------------------------------------------
resource "kubernetes_network_policy_v1" "smarter_application_group_egress" {
  count = var.enable_enhanced_security ? 1 : 0
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

    # pod-level access to MariaDB
    egress {
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name"     = "mariadb"
            "app.kubernetes.io/instance" = var.platform_name
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 3306
      }
    }

    # pod-level access to Redis
    egress {
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name"     = "redis"
            "app.kubernetes.io/instance" = var.platform_name
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 6379
      }
    }

    # pod-level access to DNS (kube-system only)
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        protocol = "UDP"
        port     = 53
      }
    }

    # pod-level access to DNS (kube-system only)
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 53
      }
    }

    # pod-level access to HTTPS (external APIs, AWS, etc.)
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = 443
      }
    }

    # pod-level access to External MySQL (remote DBs)
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = 3306
      }
    }

    # Allow SMTP (AWS SES) - port 465 (SMTPS)
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = 465
      }
    }

    # Allow SMTP (AWS SES) - port 587 (Submission)
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = 587
      }
    }

    # Allow ports 80 and 443 for ApiPlugins and get_weather function.
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = 80
      }
    }
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = 443
      }
    }
  }
}

resource "kubernetes_network_policy_v1" "smarter_bastion_egress" {
  # Network policy to allow egress from bastion pods to any external IP on ports 80 and 443.
  # This is necessary to allow bastion pods to access the internet for updates, patches,
  # and external services. All other egress is denied by default. This policy enables:
  #   - HTTP: Allow TCP 80 to any external IP (for apt-get, etc.)
  #   - HTTPS: Allow TCP 443 to any external IP (APIs, AWS, etc.)

  count = var.enable_enhanced_security ? 1 : 0
  metadata {
    name      = "smarter-bastion-egress"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/application-group" = var.platform_name
        "app.kubernetes.io/name"              = "${var.platform_name}-bastion"
      }
    }

    policy_types = ["Egress"]

    # Allow ports 80 and 443for apt-get and other HTTP traffic
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = 80
      }
    }
    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        protocol = "TCP"
        port     = 443
      }
    }

  }
}

#------------------------------------------------------------------------------
# Allow Calico VXLAN traffic between nodes
#------------------------------------------------------------------------------
resource "aws_security_group_rule" "node_to_node_vxlan" {
  count                    = var.enable_enhanced_security ? 1 : 0
  description              = "Calico VXLAN"
  type                     = "ingress"
  from_port                = 4789
  to_port                  = 4789
  protocol                 = "udp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.node_security_group_id
}

#------------------------------------------------------------------------------
# Allow kubelet API between nodes
#------------------------------------------------------------------------------
resource "aws_security_group_rule" "node_to_node_kubelet" {
  count                    = var.enable_enhanced_security ? 1 : 0
  description              = "Kubelet API"
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.node_security_group_id
}

#------------------------------------------------------------------------------
# (OPTIONAL) NodePort services
# Only include this if you actually use NodePort
#------------------------------------------------------------------------------
# resource "aws_security_group_rule" "nodes_allow_all_self" {
#   count = var.enable_enhanced_security ? 1 : 0
#   description              = "ALLOW ALL NODE TRAFFIC (restore cluster)"
#   type                     = "ingress"
#   from_port                = 0
#   to_port                  = 0
#   protocol                 = "-1"
#   security_group_id        = module.eks.node_security_group_id
#   source_security_group_id = module.eks.node_security_group_id
# }
