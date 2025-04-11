locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
  lb_name = "${var.project_name}-${var.environment}-lb"
}

# --- Security Group for Load Balancer ---
# resource "aws_security_group" "lb" {
#   name        = "${local.lb_name}-sg"
#   description = "Security group for the ${var.load_balancer_type} load balancer"
#   vpc_id      = var.vpc_id
#   tags        = merge(local.common_tags, { Name = "${local.lb_name}-sg" })
# }

# --- Ingress Rules ---
# resource "aws_security_group_rule" "allow_http_ingress" {
#   count = var.enable_http_listener ? 1 : 0

#   type              = "ingress"
#   protocol          = "tcp"
#   from_port         = 80
#   to_port           = 80
#   cidr_blocks       = var.ingress_cidr_blocks
#   security_group_id = aws_security_group.lb.id
#   description       = "Allow HTTP traffic"
# }

# resource "aws_security_group_rule" "allow_https_ingress" {
#   count = var.enable_https_listener ? 1 : 0

#   type              = "ingress"
#   protocol          = "tcp"
#   from_port         = 443
#   to_port           = 443
#   cidr_blocks       = var.ingress_cidr_blocks
#   security_group_id = aws_security_group.lb.id
#   description       = "Allow HTTPS traffic"
# }

# --- Egress Rule ---
# Allow LB to talk to any destination (targets like instances/pods in VPC)
# resource "aws_security_group_rule" "allow_all_egress" {
#   type              = "egress"
#   protocol          = "-1" # All protocols
#   from_port         = 0
#   to_port           = 0
#   cidr_blocks       = ["0.0.0.0/0"] # Allow outbound to anywhere
   # Alternatively restrict to VPC CIDR: cidr_blocks = [data.aws_vpc.selected.cidr_block] (requires adding data source for VPC)
#   security_group_id = aws_security_group.lb.id
#   description       = "Allow all outbound traffic from LB"
# }


# --- Load Balancer Resource ---
resource "aws_lb" "main" {
  name               = local.lb_name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  # security_groups    = [aws_security_group.lb.id]
  subnets            = var.public_subnet_ids # Place LB in public subnets

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = var.access_logs_s3_bucket_name
      prefix  = var.access_logs_s3_prefix
      enabled = true
    }
  }

  tags = merge(local.common_tags, {
    Name = local.lb_name
    # Add tags needed by AWS Load Balancer Controller if applicable
    # "service.beta.kubernetes.io/aws-load-balancer-internal" = tostring(var.internal)
  })
}


# --- Default Target Group (Optional) ---
resource "aws_lb_target_group" "default" {
  count = var.create_default_target_group ? 1 : 0

  port        = var.default_target_group_port
  protocol    = var.default_target_group_protocol
  vpc_id      = var.vpc_id
  target_type = var.default_target_group_type

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = var.health_check_protocol
    port                = "traffic-port" # Check on the traffic port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 6
    interval            = 15
    matcher             = "200-399" # Expect success codes for HTTP/S
  }

  tags = merge(local.common_tags, {
    Name = "${local.lb_name}-default-tg"
  })

  lifecycle {
    create_before_destroy = true # Useful if default TG needs replacement
  }
}

# --- Default Action: Forward to Default TG or Fixed Response ---
# Determine the default action based on whether the default TG is created
locals {
  default_action = var.create_default_target_group ? [{
    type             = "forward"
    target_group_arn = aws_lb_target_group.default[0].arn
    fixed_response   = null
    }] : [{ # If no default TG, return a simple 503 response
    type = "fixed-response"
    target_group_arn = null
    fixed_response = {
      content_type = "text/plain"
      message_body = "Service Unavailable - No default target group configured."
      status_code  = "503"
    }
  }]
}


# --- HTTP Listener (Optional) ---
resource "aws_lb_listener" "http" {
  count = var.enable_http_listener ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = local.default_action[0].type
    target_group_arn = lookup(local.default_action[0], "target_group_arn", null)
    dynamic "fixed_response" {
       for_each = lookup(local.default_action[0], "fixed_response", null) != null ? [local.default_action[0].fixed_response] : []
       content {
         content_type = fixed_response.value.content_type
         message_body = fixed_response.value.message_body
         status_code = fixed_response.value.status_code
       }
     }
  }

  tags = merge(local.common_tags, {
    Name = "${local.lb_name}-http-listener"
  })
}


# --- HTTPS Listener (Optional) ---
resource "aws_lb_listener" "https" {
  count = var.enable_https_listener ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08" # Reasonably modern default policy
  certificate_arn   = var.acm_certificate_arn    # Required if https listener is enabled

  default_action {
     type             = local.default_action[0].type
     target_group_arn = lookup(local.default_action[0], "target_group_arn", null)
     dynamic "fixed_response" {
        for_each = lookup(local.default_action[0], "fixed_response", null) != null ? [local.default_action[0].fixed_response] : []
        content {
          content_type = fixed_response.value.content_type
          message_body = fixed_response.value.message_body
          status_code = fixed_response.value.status_code
        }
      }
  }

  tags = merge(local.common_tags, {
    Name = "${local.lb_name}-https-listener"
  })
}