#------------------------------------------------------------------------------

resource "aws_iam_role" "AmazonEKS_CoreDNS_Role" {
  name = "AmazonEKS_CoreDNS_Role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "arn:aws:iam::${var.aws_account_id}:oidc-provider/${module.eks.oidc_provider}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com",
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:kube-system:coredns"
          }
        }
      }
    ]
  })
  tags = local.tags
}

## CoreDNS does not require an AWS managed policy by default.
## If you have a custom use case, attach a custom policy here.

resource "null_resource" "annotate-coredns" {
  provisioner "local-exec" {
    command = <<-EOT
      aws eks --region ${var.aws_region} update-kubeconfig --name ${var.namespace} --alias ${var.namespace}
      kubectl config use-context ${var.namespace}
      kubectl config set-context --current --namespace=kube-system
      kubectl annotate serviceaccount coredns -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::${var.aws_account_id}:role/${aws_iam_role.AmazonEKS_CoreDNS_Role.name} --overwrite
      kubectl rollout restart deployment coredns -n kube-system
    EOT
  }
  depends_on = [
    module.eks
  ]
}
