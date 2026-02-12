#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Mar-2022
#
# usage: Descheduler module outputs
#------------------------------------------------------------------------------

output "descheduler_release_name" {
	description = "Name of the Helm release for descheduler"
	value       = helm_release.descheduler.name
}

output "descheduler_namespace" {
	description = "Namespace where descheduler is deployed"
	value       = helm_release.descheduler.namespace
}

output "descheduler_status" {
	description = "Status of the Helm release for descheduler"
	value       = helm_release.descheduler.status
}

output "descheduler_chart_version" {
	description = "Version of the descheduler chart deployed"
	value       = helm_release.descheduler.version
}

output "descheduler_manifest" {
	description = "Rendered manifest for the descheduler Helm release"
	value       = helm_release.descheduler.manifest
}
