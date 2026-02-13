
# create an environment-specific cloudfront distribution

locals {
  s3_bucket_domain          = "${local.s3_bucket_name}.s3.${var.aws_region}.amazonaws.com"
  s3_reactjs_bucket_domain  = "${local.s3_reactjs_bucket_name}.s3.${var.aws_region}.amazonaws.com"
  cdn_domain_name           = "cdn.${local.environment_platform_domain}"
}

# see ./route53.tf for creation of aws_route53_zone.environment_platform_domain.id
resource "aws_route53_record" "cdn_environment_platform_domain" {
  zone_id = aws_route53_zone.environment_platform_domain.id
  name    = local.cdn_domain_name
  type    = "A"

  alias {
    name                   = module.cdn_environment_platform_domain.cloudfront_distribution_domain_name
    zone_id                = module.cdn_environment_platform_domain.cloudfront_distribution_hosted_zone_id
    evaluate_target_health = false
  }

}

resource "aws_cloudfront_response_headers_policy" "cors" {
  name = "CORS-Allow-Origin-${var.environment_name}"
  cors_config {
    access_control_allow_origins {
      items = ["*"]
    }
    access_control_allow_headers {
      items = ["*"]
    }
    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }
    access_control_allow_credentials = false
    origin_override = true
  }
}

module "cdn_environment_platform_domain" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 4.1"

  aliases = [local.cdn_domain_name]

  comment             = "Smarter CDN ${var.environment_name}"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  origin = {
    s3_bucket = {
      domain_name = local.s3_bucket_domain
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_bucket"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true

    # Legacy cache key and origin request settings
    cache_policy_id           = null
    origin_request_policy_id  = null

    forwarded_values = {
      query_string = true
      headers      = ["Origin"]
      cookies = {
        forward = "none"
      }
    }

    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors.id
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/static/*"
      target_origin_id       = "s3_bucket"
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = true

      cache_policy_id           = null
      origin_request_policy_id  = null

      forwarded_values = {
        query_string = true
        headers      = ["Origin"]
        cookies = {
          forward = "none"
        }
      }

      response_headers_policy_id = aws_cloudfront_response_headers_policy.cors.id
    }
  ]

  viewer_certificate = {
    acm_certificate_arn = module.acm_environment_platform_domain.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }

  tags = local.tags
}

module "cdn_reactjs_environment_domain" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 4.1"

  aliases = [local.environment_marketing_domain]

  comment             = "Smarter reactjs CDN ${var.environment_name}"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  origin = {
    s3_bucket = {
      domain_name = local.s3_reactjs_bucket_domain
    }
  }

  default_cache_behavior = {
    target_origin_id       = "s3_bucket"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true

    # Legacy cache key and origin request settings
    cache_policy_id           = null
    origin_request_policy_id  = null

    forwarded_values = {
      query_string = true
      headers      = ["Origin"]
      cookies = {
        forward = "none"
      }
    }

    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors.id
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/static/*"
      target_origin_id       = "s3_bucket"
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = true

      cache_policy_id           = null
      origin_request_policy_id  = null

      forwarded_values = {
        query_string = true
        headers      = ["Origin"]
        cookies = {
          forward = "none"
        }
      }

      response_headers_policy_id = aws_cloudfront_response_headers_policy.cors.id
    }
  ]

  viewer_certificate = {
    acm_certificate_arn = module.acm_environment_domain.acm_certificate_arn
    ssl_support_method  = "sni-only"
  }

  tags = local.tags
}
