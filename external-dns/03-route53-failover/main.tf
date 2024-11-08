terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1" # Tokyo region
}

# Common tags for all resources
locals {
  common_tags = {
    Environment = "demo"
    Project     = "route53-failover"
    Purpose     = "external-dns-and-failover-testing"
    Terraform   = "true"
  }
}

# Use default VPC and its public subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for ALBs
resource "aws_security_group" "alb" {
  name        = "alb-failover-demo"
  description = "Allow HTTP inbound traffic for failover demo"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = local.common_tags
}

# Primary ALB
resource "aws_lb" "primary" {
  name               = "alb-failover-demo-primary"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = slice(data.aws_subnets.public.ids, 0, 2)

  tags = local.common_tags
}

# Secondary ALB
resource "aws_lb" "secondary" {
  name               = "alb-failover-demo-secondary"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = slice(data.aws_subnets.public.ids, 0, 2)

  tags = local.common_tags
}

# Primary ALB Listener with Fixed Response
resource "aws_lb_listener" "primary" {
  load_balancer_arn = aws_lb.primary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "This is PRIMARY ALB"
      status_code  = "200"
    }
  }

  tags = local.common_tags
}

# Secondary ALB Listener with Fixed Response
resource "aws_lb_listener" "secondary" {
  load_balancer_arn = aws_lb.secondary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "This is SECONDARY ALB"
      status_code  = "200"
    }
  }

  tags = local.common_tags
}

# Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = "failover.test"

  tags = local.common_tags
}

# Health Check for Primary ALB
resource "aws_route53_health_check" "primary" {
  fqdn              = aws_lb.primary.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "10"

  tags = local.common_tags
}

# Primary Record (Commented out for now because it is created by external-dns)
# resource "aws_route53_record" "primary" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "www"
#   type    = "A"

#   failover_routing_policy {
#     type = "PRIMARY"
#   }

#   set_identifier = "primary"
#   health_check_id = aws_route53_health_check.primary.id

#   alias {
#     name                   = aws_lb.primary.dns_name
#     zone_id                = aws_lb.primary.zone_id
#     evaluate_target_health = true
#   }
# }

# Secondary Record (Commented out for now because it is created by external-dns)
# resource "aws_route53_record" "secondary" {
#   zone_id = aws_route53_zone.main.zone_id
#   name    = "www"
#   type    = "A"

#   failover_routing_policy {
#     type = "SECONDARY"
#   }

#   set_identifier = "secondary"

#   alias {
#     name                   = aws_lb.secondary.dns_name
#     zone_id                = aws_lb.secondary.zone_id
#     evaluate_target_health = true
#   }
# }

# Outputs
output "primary_alb_dns" {
  value = aws_lb.primary.dns_name
}

output "primary_alb_arn" {
  value = aws_lb.primary.arn
}

output "primary_listener_arn" {
  value = aws_lb_listener.primary.arn
}

output "secondary_alb_dns" {
  value = aws_lb.secondary.dns_name
}

output "zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "health_check_id" {
  value = aws_route53_health_check.primary.id
}

output "nameservers" {
  value = aws_route53_zone.main.name_servers
  description = "Nameservers for the Route53 zone"
}