#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com
#
# date:   mar-2023
#
# usage:  variables for vps module
#------------------------------------------------------------------------------
variable "aws_region" {
  description = "The region in which the origin S3 bucket was created."
  type        = string
}

variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
}

variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
}

variable "database_subnets" {
  description = "A list of database subnets"
  type        = list(string)
}

variable "elasticache_subnets" {
  description = "A list of elasticache subnets"
  type        = list(string)
}

variable "enable_ipv6" {
  description = "Requests an Amazon-provided IPv6 CIDR block with a /56 prefix length for the VPC. You cannot specify the range of IP addresses, or the size of the CIDR block."
  type        = bool
}

variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  type        = bool
}

variable "one_nat_gateway_per_az" {
  description = "Should be true if you want only one NAT Gateway per availability zone. Requires var.azs to be set, and the number of public_subnets created to be greater than or equal to the number of availability zones specified in var.azs"
  type        = bool
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
}



variable "name" {
  description = "Name to be used on all the resources as identifier"
  type        = string
}

variable "private_subnets" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
}

variable "private_subnet_tags" {
  description = "Additional tags for the private subnets"
  type        = map(string)
}

variable "public_subnets" {
  description = "A list of public subnets inside the VPC"
  type        = list(string)
}

variable "public_subnet_tags" {
  description = "Additional tags for the public subnets"
  type        = map(string)
}

variable "services_subdomain" {
  type = string
}

variable "api_domain" {
  type = string
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  type        = bool
  default     = false
}

variable "root_domain" {
  type = string
}
variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
}

variable "intra_subnets" {
  description = "A list of intra subnets inside the VPC"
  type        = list(string)
}

variable "intra_subnet_tags" {
  description = "Additional tags for the intra subnets"
  type        = map(string)
}
