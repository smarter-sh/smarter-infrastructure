#------------------------------------------------------------------------------
# written by: Miguel Afonso
#             https://www.linkedin.com/in/mmafonso/
#
# date: Aug-2021
#
# usage: build an EKS cluster load balancer
#------------------------------------------------------------------------------

output "nginx_ingress_controller_name" {
	description = "Name of the nginx ingress controller Helm release"
	value       = helm_release.traefik.name
}

output "nginx_ingress_controller_namespace" {
	description = "Namespace where the nginx ingress controller is deployed"
	value       = helm_release.traefik.namespace
}

output "nginx_ingress_controller_chart_version" {
	description = "Version of the ingress-nginx Helm chart used"
	value       = helm_release.traefik.version
}
