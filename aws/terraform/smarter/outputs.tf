#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date:       July-2023
#
# usage:      Smarter app infrastructure - Terraform outputs for this
#             Smarter environment.
#------------------------------------------------------------------------------

output "environment_name" {
  value = var.environment_name
}

output "environment_api_domain" {
  value = local.environment_api_domain
}

output "environment_platform_domain" {
  value = local.environment_platform_domain
}

output "environment_marketing_domain" {
  value = local.environment_marketing_domain
}

output "environment_namespace" {
  value = local.environment_namespace
}

output "ecr_repository_name" {
  value = local.ecr_repository_name
}

output "ecr_repository_image" {
  value = local.ecr_repository_image
}



output "root_domain" {
  value = var.root_domain
}

output "mysql_host" {
  value = var.mysql_host
}

output "mysql_port" {
  value = var.mysql_port
}

output "mysql_database" {
  value = local.mysql_database
}
output "mysql_root_user" {
  value = var.mysql_root_username
}

output "s3_bucket_name" {
  value = local.s3_bucket_name
}

output "s3_backup_bucket_name" {
  value = local.s3_backup_bucket_name
}

output "s3_exports_bucket_name" {
  value = local.s3_exports_bucket_name
}

output "issuer_platform_manifest" {
  value = local.issuer_platform_manifest
}

output "domain" {
  value = local.environment_platform_domain
}

output "namespace" {
  value = local.environment_namespace
}

output "aws_region" {
  value = var.aws_region
}

output "hosted_zone_id" {
  value = aws_route53_zone.environment_platform_domain.zone_id
}

# The IAM roles of the pods (iam-irsa.tf). The deploy passes them to the Helm
# chart, from the GitHub environment's secrets AWS_IAM_ROLE_ARN and
# AWS_BACKUP_IAM_ROLE_ARN.
output "smarter_iam_role_arn" {
  value = module.smarter_irsa.iam_role_arn
}

output "smarter_backup_iam_role_arn" {
  value = module.smarter_backup_irsa.iam_role_arn
}

# The deploy user's access key (iam-deploy.tf), for the GitHub environment's
# secrets AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY. Read the secret with
# terragrunt output -raw deploy_secret_access_key.
output "deploy_access_key_id" {
  value = local.is_local_environment ? null : aws_iam_access_key.deploy[0].id
}

output "deploy_secret_access_key" {
  value     = local.is_local_environment ? null : aws_iam_access_key.deploy[0].secret
  sensitive = true
}

# The local environment's Docker user (iam-local.tf), for the smarter
# repository's .env.
output "local_docker_access_key_id" {
  value = local.is_local_environment ? aws_iam_access_key.local_docker[0].id : null
}

output "local_docker_secret_access_key" {
  value     = local.is_local_environment ? aws_iam_access_key.local_docker[0].secret : null
  sensitive = true
}
