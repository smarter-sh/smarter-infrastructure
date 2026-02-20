#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com
#
# date: mar-2023
#
# usage: outputs for vps module
#------------------------------------------------------------------------------
output "root_domain_zone_id" {
  description = "The zone ID of the root domain"
  value       = data.aws_route53_zone.root_domain.zone_id
}

output "services_subdomain_zone_id" {
  description = "The zone ID of the services subdomain"
  value       = aws_route53_zone.services_subdomain.zone_id
}

output "services_subdomain_name" {
  description = "The name of the services subdomain zone"
  value       = aws_route53_zone.services_subdomain.name
}

output "services_subdomain_name_servers" {
  description = "The name servers for the services subdomain"
  value       = aws_route53_zone.services_subdomain.name_servers
}

output "services_subdomain_ns_fqdn" {
  description = "The FQDN of the services subdomain NS record"
  value       = aws_route53_record.services_subdomain_ns.fqdn
}



output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the VPC"
  value       = module.vpc.vpc_arn
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "vpc_ipv6_cidr_block" {
  description = "The IPv6 CIDR block of the VPC"
  value       = module.vpc.vpc_ipv6_cidr_block
}

output "vpc_main_route_table_id" {
  description = "The ID of the main route table associated with this VPC"
  value       = module.vpc.vpc_main_route_table_id
}

output "vpc_owner_id" {
  description = "The ID of the AWS account that owns the VPC"
  value       = module.vpc.vpc_owner_id
}

output "azs" {
  description = "A list of availability zones specified as argument to this module"
  value       = module.vpc.azs
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets"
  value       = module.vpc.public_subnet_arns
}

output "public_subnets_cidr_blocks" {
  description = "List of cidr_blocks of public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets"
  value       = module.vpc.private_subnet_arns
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "intra_subnets" {
  description = "List of intra subnet IDs"
  value       = module.vpc.intra_subnets
}

output "intra_subnet_arns" {
  description = "List of ARNs of intra subnets"
  value       = module.vpc.intra_subnet_arns
}

output "intra_subnets_cidr_blocks" {
  description = "List of cidr_blocks of intra subnets"
  value       = module.vpc.intra_subnets_cidr_blocks
}

output "database_subnets" {
  description = "List of database subnet IDs"
  value       = module.vpc.database_subnets
}

output "database_subnet_arns" {
  description = "List of ARNs of database subnets"
  value       = module.vpc.database_subnet_arns
}

output "database_subnets_cidr_blocks" {
  description = "List of cidr_blocks of database subnets"
  value       = module.vpc.database_subnets_cidr_blocks
}

output "elasticache_subnets" {
  description = "List of elasticache subnet IDs"
  value       = module.vpc.elasticache_subnets
}

output "elasticache_subnet_arns" {
  description = "List of ARNs of elasticache subnets"
  value       = module.vpc.elasticache_subnet_arns
}

output "elasticache_subnets_cidr_blocks" {
  description = "List of cidr_blocks of elasticache subnets"
  value       = module.vpc.elasticache_subnets_cidr_blocks
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = module.vpc.igw_id
}

output "igw_arn" {
  description = "The ARN of the Internet Gateway"
  value       = module.vpc.igw_arn
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.vpc.natgw_ids
}

output "natgw_interface_ids" {
  description = "List of Network Interface IDs assigned to NAT Gateways"
  value       = module.vpc.natgw_interface_ids
}

output "nat_ids" {
  description = "List of allocation ID of Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_ids
}

output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_public_ips
}
