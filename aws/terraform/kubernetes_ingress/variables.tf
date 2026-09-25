#------------------------------------------------------------------------------
# written by:   Lawrence McDaniel
#               https://lawrencemcdaniel.com
#
# date:         Feb-2026
#
# usage:        variables for the default cluster-wide traefik ingress controller
#------------------------------------------------------------------------------

variable "services_subdomain" {
  type = string
}

variable "root_domain" {
  description = "Root domain (route53 zone) for the default cluster ingress."
  type        = string
}

variable "namespace" {
  type = string
}

variable "stack_name" {
  type = string
}

variable "tags" {
  description = "A map of tags to add to all resources. Tags added to launch configuration or templates override these values for ASG Tags only."
  type        = map(string)
  default     = {}
}

variable "aws_region" {
    description = "AWS region to deploy to."
    type        = string
}

variable "cluster_name" {
    description = "Name of the EKS cluster to create."
    type        = string
}
