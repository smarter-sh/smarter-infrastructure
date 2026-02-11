#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: July-2025
#
data "aws_iam_policy" "AmazonEKS_CNI_Policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role" "AmazonEKS_VPC_CNI_Role" {
  name = "AmazonEKS_VPC_CNI_Role"
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
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:kube-system:aws-node"
          }
        }
      }
    ]
  })
  tags = merge(
    local.tags,
    {
      "smarter"  = "true",
    }
  )
}

resource "aws_iam_role_policy_attachment" "aws_vpc_cni_policy" {
  role       = aws_iam_role.AmazonEKS_VPC_CNI_Role.name
  policy_arn = data.aws_iam_policy.AmazonEKS_CNI_Policy.arn
}

resource "null_resource" "annotate-aws-node" {
  provisioner "local-exec" {
    command = <<-EOT
      aws eks --region ${var.aws_region} update-kubeconfig --name ${var.namespace} --alias ${var.namespace}
      kubectl config use-context ${var.namespace}
      kubectl config set-context --current --namespace=kube-system
      kubectl annotate serviceaccount aws-node -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::${var.aws_account_id}:role/${aws_iam_role.AmazonEKS_VPC_CNI_Role.name} --overwrite
      kubectl rollout restart daemonset aws-node -n kube-system
    EOT
  }
  depends_on = [
    module.eks
  ]
}
