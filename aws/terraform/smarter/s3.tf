#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date:       July-2023
#
# usage:      Smarter app infrastructure - Terraform configuration
#             for AWS S3 buckets and policies
#------------------------------------------------------------------------------


module "environment_storage" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.10"

  bucket                   = local.s3_bucket_name
  block_public_acls        = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  acl                      = "public-read"
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
  tags                     = local.tags

  attach_policy = true
  policy = data.aws_iam_policy_document.public_ui_chat.json

  versioning = {
    enabled = false
  }
}


data "aws_iam_policy_document" "public_ui_chat" {
  statement {
    sid     = "AllowPublicReadForAllObjects"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = ["arn:aws:s3:::${local.s3_bucket_name}/*"]
  }
}

# to prevent public ACLs from being blocked by the bucket policy
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = module.environment_storage.s3_bucket_id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


# Database backups get their own private bucket. The environment bucket above is
# public-read, because it serves the chat widget and static assets through
# CloudFront, so nothing private can be stored there. The deploy points the
# chart's backup CronJob (databaseScheduledBackup.s3Uri) at this bucket.
module "backup_storage" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.10"

  bucket = local.s3_backup_bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  # refuse any request that isn't made over TLS
  attach_deny_insecure_transport_policy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning = {
    enabled = true
  }

  tags = local.tags
}
