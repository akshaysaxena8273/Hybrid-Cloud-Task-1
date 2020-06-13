
provider "aws" {
	region = "ap-south-1"
}

resource "aws_key_pair" "task1key" {
  key_name   = "task1key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAqpGktKI8BbsfyuauxagouK9uqrQtZkb8RWrMpC4dP9yVVpU0wNyiivi1Eub9dCj+T+EFmQ0eHfKHux1bCNQeMSQ+Sqh8qhz+ZXy5rIBZQKsRk5/PcqZSS7brwU6TOKhprcsdr0unLyRHEd0bIducReU+itQ5oDBJuu0X7E1r/kaTHoHJ4b0D6GcyfNBfUlHjbhc5OyXLy5n27JbjxceRfBrr4tg8f3XT35q1CwPovvYYNTQODWCoxsn6L5uCgX1RDno9/mqFkxep2npQgJwvUrViQOGCEkxY91KvGhDsv3eZCdXmfzbXPAm/QHicy7Dv5VCykTDnPmVFT3mH8FmxFw=="
}
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
  tags = {
    Name = "allow_tls"
  }
}

variable amiid {
  default="ami-052c08d70def0ac62"
}

resource "aws_instance" "ec2_terra" {
  ami           = "${var.amiid}"
  instance_type = "t2.micro"
  key_name = "task1key"
  tags = {
    Name = "ec2_terra"
  }
}

resource "aws_ebs_volume" "ebs_terra" {
  availability_zone = "ap-south-1a"
  size              = 1

  tags = {
    Name = "ebs_terra"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ebs_terra.id}"
  instance_id = "${aws_instance.ec2_terra.id}"
}

resource "aws_s3_bucket" "s3_terra" {
  bucket = "myterrabucket-s3"
  acl    = "public-read"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


resource "aws_s3_bucket_object" "imageobject" {
  bucket = "${aws_s3_bucket.s3_terra.id}"
  key    = "5.jpg"
  source = "5.jpg"
  }



  resource "aws_cloudfront_distribution" "s3_terra_distribution" {
  origin {
    domain_name = "myterrabucket-s3.s3.amazonaws.com"
    origin_id   = "S3-myterrabucket-s3"

    custom_origin_config {
      http_port=80
      https_port=80
      origin_protocol_policy = "match-viewer"
      origin_ssl_protocols=["TLSv1","TLSv1.1","TLSv1.2"]
      }
  }

enabled = true

default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-myterrabucket-s3"

    forwarded_values {  
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-myterrabucket-s3"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "allow-all"
  }

  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-myterrabucket-s3"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "allow-all"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["US", "CA"]
    }
  }
  
  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
