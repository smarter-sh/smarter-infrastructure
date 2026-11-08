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
  block_public_policy      = false
  ignore_public_acls       = false
  restrict_public_buckets  = false
  acl                      = "public-read"
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
  tags                     = local.tags

  attach_policy = true
  policy        = data.aws_iam_policy_document.public_ui_chat.json

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


# Users' data exports get their own private bucket. "Download My Data", in the
# web console's user menu, zips the manifest of every resource that a user owns
# and emails them a presigned link to it that expires after 24 hours. A link to
# the public environment bucket above could never expire, so the zip files go
# here instead. The platform derives the name the same way
# (smarter_settings.aws_s3_exports_bucket_name), so it needs no new setting.
#
# Each zip file is a few hundred KB, and lives for a day: the lifecycle rule
# deletes it after one day, and the platform's own Celery Beat task deletes
# any that the rule hasn't reached yet once its link has expired. Storage cost
# rounds to zero.
module "exports_storage" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.10"

  bucket = local.s3_exports_bucket_name

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerEnforced"

  # refuse any request that isn't made over TLS, presigned downloads included
  attach_deny_insecure_transport_policy = true

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  # no versioning: a deleted export must really be gone, not kept as a noncurrent version
  versioning = {
    enabled = false
  }

  lifecycle_rule = [
    {
      id      = "expire-data-exports"
      enabled = true
      filter = {
        prefix = "data-exports/"
      }
      expiration = {
        days = 1
      }
      abort_incomplete_multipart_upload_days = 1
    }
  ]

  tags = local.tags
}
