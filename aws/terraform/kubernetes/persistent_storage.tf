#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Feb-2026
#
# usage: create an a gp3 storage class for EKS cluster
#
# Technical documentation:
# - https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/storage_class
# - https://kubernetes.io/blog/2017/03/dynamic-provisioning-and-storage-classes-kubernetes/
#------------------------------------------------------------------------------


resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
  }
  storage_provisioner = "kubernetes.io/aws-ebs"
  parameters = {
    type = "gp3"
    fsType = "ext4"
  }
  reclaim_policy        = "Delete"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true
}
