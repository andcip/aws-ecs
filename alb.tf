data "aws_lb" "lb_trigger" {
  count = try(var.trigger.lb, null) != null ? 1 : 0
  name  = var.trigger.lb.name
}

data "aws_lb_listener" "lb_listener" {
  count             = try(var.trigger.lb, null) != null ? 1 : 0
  load_balancer_arn = data.aws_lb.lb_trigger[0].arn
  port              = 443
}

resource "aws_lb_target_group" "service_tg" {
  count       = try(var.trigger.lb, null) == null ? 0 : 1
  name        = "${var.service.name}-LBTG"
  port        = var.service.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    healthy_threshold = 3
    path              = var.healthcheck.path
    port              = var.service.port
  }
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
  }
}


resource "aws_lb_listener_rule" "service" {
  count        = try(var.trigger.lb, null) == null ? 0 : length(var.trigger.lb.rules)
  listener_arn = data.aws_lb_listener.lb_listener[0].arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_tg[0].arn
  }

  condition {
    path_pattern {
      values = var.trigger.lb.rules[count.index].path_patterns
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.rules[count.index].hosts != null ?  [true] : []
    content {
      host_header {
        values = var.trigger.lb.rules[count.index].hosts
      }
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.rules[count.index].http_headers != null ? var.trigger.lb.rules[count.index].http_headers : []
    content {
      http_header {
        http_header_name = condition.key
        values           = condition.value
      }
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.rules[count.index].http_methods != null ? [true] : []
    content {
      http_request_method {
        values = var.trigger.lb.rules[count.index].http_methods
      }
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.rules[count.index].source_ips != null ? [true] : []
    content {
      source_ip {
        values = var.trigger.lb.rules[count.index].source_ips
      }
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.rules[count.index].query_string != null ? [true] : []
    content {
      query_string {
        value = var.trigger.lb.rules[count.index].query_string
      }
    }
  }

}
