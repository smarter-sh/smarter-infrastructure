#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Mar-2023
#
# usage: create an EKS cluster
#------------------------------------------------------------------------------
variable "stack_name" {
  type = string
}

variable "tags" {
  description = "A map of tags to add to all resources. Tags added to launch configuration or templates override these values for ASG Tags only."
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}
