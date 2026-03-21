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


resource "kubernetes_network_policy" "smarter_mariadb_allow_backend" {
  metadata {
    name      = "mariadb-allow-backend"
    namespace = "default"
  }

  spec {
    pod_selector {
      match_labels = {
        app.kubernetes.io/name = "mariadb"
        app.kubernetes.io/instance = var.platform_name
      }
    }

    policy_types = ["Ingress"]

  ingress {
    from {
      pod_selector {
        match_labels = {
          app.kubernetes.io/application-group = var.platform_name
        }
      }
    }
    ports {
      protocol = "TCP"
      port     = 3306
    }
  }

  }
}

resource "kubernetes_network_policy" "smarter_redis_allow_backend" {
  metadata {
    name      = "redis-allow-backend"
    namespace = "default"
  }

  spec {
    pod_selector {
      match_labels = {
        app.kubernetes.io/name     = "redis"
        app.kubernetes.io/instance = var.platform_name
        app.kubernetes.io/component = "master"
      }
    }

    policy_types = ["Ingress"]

    ingress {
      from {
        pod_selector {
          match_labels = {
            app.kubernetes.io/application-group = var.platform_name
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = 6379
      }
    }
  }
}

resource "kubernetes_network_policy" "smarter_default_deny_mariadb" {
  metadata {
    name      = "default-deny-mariadb"
    namespace = "smarter-ubc-prod"
  }
  spec {
    pod_selector {
      match_labels = {
        app.kubernetes.io/name = "mariadb"
        app.kubernetes.io/instance = var.platform_name
      }
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "smarter_default_deny_redis" {
  metadata {
    name      = "default-deny-redis"
    namespace = "smarter-ubc-prod"
  }
  spec {
    pod_selector {
      match_labels = {
        app.kubernetes.io/name = "redis"
        app.kubernetes.io/instance = var.platform_name
        app.kubernetes.io/component = "master"
      }
    }
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "smarter_default_deny_smarter_application_group" {
  metadata {
    name      = "default-deny-smarter-application-group"
    namespace = "smarter-ubc-prod"
  }
  spec {
    pod_selector {
      match_labels = {
        app.kubernetes.io/application-group = var.platform_name
      }
    }
    policy_types = ["Ingress"]
  }
}


resource "kubernetes_network_policy" "smarter_application_group_egress" {
  metadata {
    name      = "smarter-application-group-egress"
    namespace = "default"
  }

  spec {
    pod_selector {
      match_labels = {
        app.kubernetes.io/application-group = var.platform_name
      }
    }

    policy_types = ["Egress"]

    egress {
      to {
        pod_selector {
          match_labels = {
            app.kubernetes.io/application-group = var.platform_name
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 3306
      }
    }

    egress {
      to {
        pod_selector {
          match_labels = {
            app.kubernetes.io/application-group = var.platform_name
          }
        }
      }
      ports {
        protocol = "TCP"
        port     = 6379
      }
    }
  }
}
