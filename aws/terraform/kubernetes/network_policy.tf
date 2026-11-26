###############################################################################
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Mar-2026
#
# usage: setup Kubernetes network policies for smarter application group.
# This file installs Calico in policy-only mode, to enforce Kubernetes network
# policies, and sets up a set of those policies to tightly control pod-to-pod
# communication within the cluster. The AWS VPC CNI remains the cluster's network
# plugin and still assigns every pod its IP address.
# A collection of kubernetes_network_policy_v1 resources are defined that
# dictate the kinds of traffic that can both enter and leave the various kinds
# of pods within the application group.
#
# The policies accomplish the following:
# - Restrict access to MariaDB and Redis pods, allowing only authorized backend pods
#   (identified by specific labels) to connect on their respective ports.
# - Enforce a default-deny ingress policy for MariaDB, Redis, and the application group
#   in the production namespace, blocking all traffic except what is explicitly allowed.
# - Limit egress from application group pods to the ports they use, which reduces the
#   risk of lateral movement inside the cluster. It is not an exfiltration control:
#   the pods may reach any internet address on 443, as API plugins, MCP clients, web
#   search and LLM providers at custom endpoints need, and on 80, 587 and 3306. See
#   "Supply-Chain Security" in the Smarter docs (docs.smarter.sh).
#   These policies provide fine-grained, dynamic, and label-based network segmentation
#   at the pod level, which cannot be achieved with cloud provider security groups alone.
#   They help ensure that only intended services can communicate, improving the security
#   posture of the Smarter platform.
###############################################################################

locals {
  db_port    = 3306 # Default port for MariaDB
  cache_port = 6379 # Default port for Redis
  app_port   = 8000 # the app's containerPort (helm/charts/smarter/values.yaml)

  # Loki's ports (the smarter Helm chart's loki subchart, loki.server in its values)
  loki_http_port = 3100
  loki_grpc_port = 9095

  # the namespace of the Traefik ingress controller (../kubernetes_ingress/main.tf),
  # the only caller outside the application's namespace.
  ingress_namespace = "traefik"

  # the application-group of the tool worker's pods (the smarter Helm chart's workerTools,
  # templates/deployment-worker-tools.yaml). It is not var.platform_name, so that none of the
  # platform's policies apply to them: see smarter_tools_egress.
  tools_group = "${var.platform_name}-tools"

  # the addresses that the tool worker may not reach on the internet ports: the VPC, with every
  # node, pod and the private EKS endpoint, the other private ranges, and link-local, with the
  # instance metadata service, which hands out the node's IAM role.
  tools_private_cidrs = [
    data.aws_vpc.smarter_vpc.cidr_block,
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "100.64.0.0/10",
    "169.254.0.0/16",
  ]
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
# On EKS, Calico runs in policy-only mode: the AWS VPC CNI (the aws-node
# daemonset) stays the CNI plugin and the IPAM, so pods keep their VPC addresses,
# and Calico's Felix agent only enforces network policy, with iptables rules on
# each node. kubernetesProvider and cni.type state this explicitly; the operator
# would otherwise infer the same values from EKS and the aws-node daemonset.
#
# Because the VPC CNI does the networking, the IP pool is not used to assign pod
# addresses, and there is no overlay between nodes (encapsulation = "None"). The
# values below match the Installation the operator reports on the running
# cluster. Note that encapsulation is a field of each IP pool, not of
# calicoNetwork: placed on calicoNetwork it is silently pruned by the API server.
#
# The chart is pinned so that a new environment gets the same Calico as the
# running ones. Upgrade it deliberately: https://docs.tigera.io/calico/latest/operations/upgrading/
#------------------------------------------------------------------------------
resource "helm_release" "calico" {
  count            = var.enable_enhanced_security ? 1 : 0
  name             = "calico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  version          = "v3.31.4"
  namespace        = "tigera-operator"
  create_namespace = true

  values = [
    yamlencode({
      installation = {
        kubernetesProvider = "EKS"
        cni = {
          type = "AmazonVPC"
        }
        calicoNetwork = {
          bgp = "Disabled"

          ipPools = [
            {
              blockSize     = 26
              cidr          = data.aws_vpc.smarter_vpc.cidr_block
              encapsulation = "None"
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
# Network policy that admits ingress traffic to application group pods from two
# sources only:
#
# - any pod in the same namespace, which the workers, beat, the init job and the
#   bastion need to reach each other.
# - the Traefik ingress controller, on the app's port only, which is how every
#   request from the internet arrives.
#
# A namespace_selector {} with no labels would match every namespace in the
# cluster, so the same-namespace rule is a pod_selector {} with no namespace
# selector, which Kubernetes limits to the policy's own namespace. All other
# ingress is still denied by the default-deny policy.
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

    # every pod in this namespace
    ingress {
      from {
        pod_selector {}
      }
    }

    # the Traefik ingress controller, on the app's port only
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = local.ingress_namespace
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = local.app_port
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

    # the tool worker, for SQL plugins whose connection is this MariaDB, e.g. Stackademy's.
    # It has no credentials of its own: each SQL call brings its connection's.
    ingress {
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/application-group" = local.tools_group
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

    # the tool worker, which takes its tasks from the Celery broker, returns their results
    # to the result backend, and reads extension archives from the cache.
    ingress {
      from {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/application-group" = local.tools_group
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
#   - Loki: Allow TCP 3100 and 9095 to Loki pods in the same namespace
#   - DNS: Allow UDP/TCP 53 to kube-system namespace (DNS resolution)
#   - HTTPS: Allow TCP 443 to any external IP (LLM providers, AWS, API plugins,
#     MCP clients, web search)
#   - External MySQL: Allow TCP 3306 to any external IP (SQL plugins' databases)
#   - SMTP: Allow TCP 587 to any external IP (AWS SES)
#   - HTTP: Allow TCP 80 to any external IP (API plugins on plain HTTP)
#
# The in-cluster rules are scoped to their pods. The four internet rules are
# scoped by port only, because those features call hosts that a manifest author
# or the LLM chooses. Those features now run in the tool worker
# (smarter_tools_egress) where the chart's workerTools is enabled; once it is, in
# every environment, 80 and 3306 can be closed here, and 443 narrowed (ADR-038,
# phase 3).
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

    # pod-level access to Loki, which stores the pods' logs (the smarter Helm chart's
    # loki subchart): Alloy pushes to it and the app's MCP Server queries it on
    # loki_http_port, and Loki calls its own compactor on loki_grpc_port.
    egress {
      to {
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name"     = "loki"
            "app.kubernetes.io/instance" = var.platform_name
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = local.loki_http_port
      }
      ports {
        protocol = "TCP"
        port     = local.loki_grpc_port
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

    # Allow SMTP (AWS SES) - port 587 (Submission, with STARTTLS). The only SMTP
    # port Smarter uses: each environment's aws-ses-config Secret
    # (../smarter/kubernetes-ses.tf) sets SMTP_PORT 587 and SMTP_USE_TLS. Port 465
    # (SMTPS) is closed: an open port that nothing uses is only a way out for a
    # compromised dependency.
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

    # Allow port 80 for ApiPlugins and the get_weather function.
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
    # TCP 443 for ApiPlugins is covered by the HTTPS rule above.
  }
}

# ------------------------------------------------------------------------------
# Network policy for the egress of the tool worker (ADR-038), the pods whose
# application-group is local.tools_group. It executes the tool calls that the
# app resolves: API, SQL and MCP calls, extension tools and web search page
# fetches, to hosts that manifest authors, extension authors and the LLM choose.
# It may reach:
#   - Redis: TCP 6379, the Celery broker, the result backend and the cache
#   - MariaDB: TCP 3306, for SQL plugins whose connection is the platform's MariaDB
#   - DNS: UDP/TCP 53 to kube-system
#   - the internet: TCP 443, 80 and 3306, except local.tools_private_cidrs
#
# Nothing else: not the app, the other workers, Loki, the EKS api, the nodes or
# the instance metadata service. No ingress policy admits any traffic to these
# pods, so default-deny-all denies all of it: nothing calls the tool worker.
# ------------------------------------------------------------------------------
resource "kubernetes_network_policy_v1" "smarter_tools_egress" {
  count = var.enable_enhanced_security ? 1 : 0
  metadata {
    name      = "smarter-tools-egress"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/application-group" = local.tools_group
      }
    }

    policy_types = ["Egress"]

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
        port     = local.cache_port
      }
    }

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
        port     = local.db_port
      }
    }

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
      ports {
        protocol = "TCP"
        port     = 53
      }
    }

    egress {
      to {
        ip_block {
          cidr   = "0.0.0.0/0"
          except = local.tools_private_cidrs
        }
      }
      ports {
        protocol = "TCP"
        port     = 443
      }
      ports {
        protocol = "TCP"
        port     = 80
      }
      ports {
        protocol = "TCP"
        port     = local.db_port
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

# No rule for Calico VXLAN (UDP 4789): in policy-only mode the VPC CNI carries
# pod traffic between nodes and Calico uses no overlay.

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
