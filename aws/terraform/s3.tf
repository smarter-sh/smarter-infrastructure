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

module "reactjs_storage" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.10"

  bucket                   = local.s3_reactjs_bucket_name
  block_public_acls        = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
  acl                      = "public-read"
  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"
  tags                     = local.tags

  attach_policy = true
  policy = data.aws_iam_policy_document.public_reactjs.json

  versioning = {
    enabled = false
  }
}

data "aws_iam_policy_document" "public_reactjs" {
  statement {
    sid     = "AllowPublicReadForAllObjects"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = ["arn:aws:s3:::${local.s3_reactjs_bucket_name}/*"]
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
