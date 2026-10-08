# --------------------------------------------------
# S3 BUCKET
# --------------------------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "${var.project_name}-"

  tags = {
    Name = var.project_name
    Environment = "production"
  }
}

# Keep bucket ownership with the bucket owner
resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# --------------------------------------------------
# CLOUDFRONT ORIGIN ACCESS CONTROL
# --------------------------------------------------

resource "aws_cloudfront_origin_access_control" "frontend" {
  name = "${var.project_name}-oac"
  description = "CloudFront access to frontend S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

# --------------------------------------------------
# CLOUDFRONT DISTRIBUTION
# --------------------------------------------------

resource "aws_cloudfront_distribution" "frontend" {

  enabled = true

  comment = "Smart Task Frontend"

  default_root_object = "index.html"

  # S3 origin
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id = "S3-${aws_s3_bucket.frontend.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Default cache behavior
  default_cache_behavior {

    target_origin_id = "S3-${aws_s3_bucket.frontend.id}"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    compress = true

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  # React/Vite SPA routing
  custom_error_response {
    error_code = 403
    response_code = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code = 404
    response_code = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # CloudFront default HTTPS certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  price_class = "PriceClass_100"

  tags = {
    Name = var.project_name
    Environment = "production"
  }
}

# --------------------------------------------------
# S3 BUCKET POLICY
# Allow ONLY this CloudFront distribution to read
# --------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "frontend_bucket_policy" {

  statement {
    sid = "AllowCloudFrontReadOnly"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.frontend.arn}/*"
    ]

    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.frontend.id}"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket_policy.json

  depends_on = [
    aws_cloudfront_distribution.frontend
  ]
}



