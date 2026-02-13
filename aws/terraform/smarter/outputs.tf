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

output "s3_reactjs_bucket_name" {
  value = local.s3_reactjs_bucket_name
}
