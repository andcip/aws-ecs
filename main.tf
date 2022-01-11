data "aws_ecr_repository" "service_repository" {
  name = var.service.name
}
data "aws_region" "current" {}

data "aws_sns_topic" "system-alarm" {
  count = var.alarm_topic_name == null ? 0 : 1
  name  = var.alarm_topic_name
}

data "aws_service_discovery_dns_namespace" "service_registry" {
  count = var.service_registry_name != null ? 1 : 0
  name  = var.service_registry_name
  type  = "DNS_PRIVATE"
}

data "aws_iam_policy" "task_execution_role_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy" "aws_service_autoscale_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}

resource "aws_iam_role" "task_execution_role" {
  name        = "${var.service.name}-task-execution-role"
  description = "Allow containers agent to communicate with the cluster"
  tags        = {
    Name = "task-execution-role"
  }

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task_execution_role_attach" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = data.aws_iam_policy.task_execution_role_policy.arn
}

resource "aws_iam_role" "task_role" {
  name        = "${var.service.name}-task-role"
  description = "Assume role for ecs task"
  tags        = {
    Name = "task-role"
  }

  assume_role_policy = jsonencode({
    version : "2012-10-17",
    statement : [
      {
        action : "sts:AssumeRole",
        principal : {
          service : "ecs-tasks.amazonaws.com"
        },
        effect : "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy" "task_role_policy" {
  name = "${var.service.name}-task-policy"
  role = aws_iam_role.task_role.id

  policy = jsonencode({

    version : "2012-10-17",
    statement : [
      {
        effect : "Allow",
        action : [
          "xray:PutTelemetryRecords",
          "xray:PutTraceSegments"
        ],
        resources : "*"
      }
    ]
  })
}

resource "aws_service_discovery_service" "ecs_discovery_service" {
  count = var.service_registry_name != null ? 1 : 0
  name  = var.service.name

  dns_config {
    namespace_id   = data.aws_service_discovery_dns_namespace.service_registry[0].id
    routing_policy = "WEIGHTED"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_cloudwatch_log_group" "task_log_group" {
  name              = "/ecs/${var.service.name}-log-group"
  retention_in_days = 60
}

locals {
  environment_variables = [for n, v in var.service.env : { name : n, value : v }]

  healthcheck_command = var.service.healthcheck.path != null && var.service.healthcheck.port != null ? "curl -f http://localhost:${var.service.healthcheck.port}${var.service.healthcheck.path} || exit 1" : "exit 0"

}

##TODO move to template file
resource "aws_ecs_task_definition" "service_task_definition" {
  container_definitions    = jsonencode([
    {
      name             = var.service.name
      cpu              = var.service_params.cpu
      memory           = var.service_params.memory
      environment      = local.environment_variables
      essential        = true
      image            = "${data.aws_ecr_repository.service_repository.repository_url}:${var.service.version}"
      tags             = []
      portMappings     = [
        {
          containerPort = var.service.port
          hostPort      = var.service.port
          protocol      = "tcp"
        }
      ]
      startTimeout     = 10
      stopTimeout      = 10
      healthCheck      = {
        command  = [local.healthcheck_command]
        interval = 30
        timeout  = 10
        retries  = 5
      }
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.task_log_group.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
  family                   = var.service.name
  network_mode             = "awsvpc"
  cpu                      = var.service_params.cpu
  memory                   = var.service_params.memory
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  requires_compatibilities = [
    "FARGATE"
  ]
}

data "aws_subnets" "subnets" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "tag:Type"
    values = [var.service_params.is_public ? "Public" : "Private"]
  }
}

data "aws_lb" "lb_trigger" {
  count = try(var.trigger.lb, null) != null ? 1 : 0
  arn   = var.trigger.lb.arn
}


resource "aws_security_group" "service_sg" {
  name   = "${var.service.name}-service-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.service.port
    to_port         = var.service.port
    security_groups = var.trigger.lb != null ? data.aws_lb.lb_trigger[0].security_groups : null
    cidr_blocks     = var.trigger.lb != null ? null : []
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.service.name}-service-sg"
  }
}

resource "aws_ecs_service" "service" {

  name                               = var.service.name
  cluster                            = var.existing_cluster_name
  task_definition                    = aws_ecs_task_definition.service_task_definition.arn
  desired_count                      = var.service_params.desired_count
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  force_new_deployment               = true

  capacity_provider_strategy {
    capacity_provider = var.service.capacity_provider.provider
    base              = var.service.capacity_provider.base
    weight            = var.service.capacity_provider.weight
  }

  network_configuration {
    assign_public_ip = var.service_params.is_public
    subnets          = data.aws_subnets.subnets.*.id
    security_groups  = [aws_security_group.service_sg.id]
  }

  dynamic "service_registries" {
    for_each = var.service_registry_name != null ? [true] : []
    content {
      registry_arn = aws_service_discovery_service.ecs_discovery_service[0].arn
    }
  }

  dynamic "load_balancer" {
    for_each = try(var.trigger.lb, null) == null ? [] : [true]

    content {
      target_group_arn = aws_lb_target_group.service_tg[0].arn
      container_name   = var.service.name
      container_port   = var.service.port
    }
  }

  //tags = local.common_tags

}

resource "aws_cloudwatch_log_group" "service_log_group" {
  depends_on        = [aws_ecs_service.service]
  name              = "/ecs/${var.service.name}"
  retention_in_days = 90
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
    path              = var.service.healthcheck.path
    port              = var.service.port
  }
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
  }
}


resource "aws_lb_listener_rule" "service" {
  count        = try(var.trigger.lb, null) == null ? 0 : 1
  listener_arn = var.trigger.lb.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service_tg[count.index].arn
  }

  condition {
    path_pattern {
      values = var.trigger.lb.conditions.path_patterns
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.conditions.hosts != null ?  [true] : []
    content {
      host_header {
        values = var.trigger.lb.conditions.hosts
      }
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.conditions.http_headers != null ? var.trigger.lb.conditions.http_headers : []
    content {
      http_header {
        http_header_name = condition.key
        values           = condition.value
      }
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.conditions.http_methods != null ? [true] : []
    content {
      http_request_method {
        values = var.trigger.lb.conditions.http_methods
      }
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.conditions.source_ips != null ? [true] : []
    content {
      source_ip {
        values = var.trigger.lb.conditions.source_ips
      }
    }
  }

  dynamic "condition" {
    for_each = var.trigger.lb.conditions.query_string != null ? [true] : []
    content {
      query_string {
        value  = var.trigger.lb.conditions.query_string
      }
    }
  }

}

resource "aws_iam_role" "service_autoscaling_role" {
  count       = var.service_autoscaling.scale_on_cpu || var.service_autoscaling.scale_on_memory ? 1 : 0
  name        = "${var.service.name}-service-autoscaling-role"
  description = "IAM role allowing ecs service to scale automatically"
  path        = "/"
  tags        = {
    Name = "service-autoscaling-role"
  }

  assume_role_policy = jsonencode({
    version : "2012-10-17",
    statement : [
      {
        action : "sts:AssumeRole",
        principal : {
          service : "application-autoscaling.amazonaws.com"
        },
        effect : "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "service_autoscaling_role_policy_attach" {
  count      = var.service_autoscaling.scale_on_cpu || var.service_autoscaling.scale_on_memory ? 1 : 0
  role       = aws_iam_role.service_autoscaling_role[0].name
  policy_arn = data.aws_iam_policy.aws_service_autoscale_role.arn
}


resource "aws_appautoscaling_target" "ecs_target" {
  count = var.service_autoscaling.scale_on_cpu || var.service_autoscaling.scale_on_memory ? 1 : 0

  depends_on         = [aws_ecs_service.service]
  max_capacity       = var.service_autoscaling.max_instance_number
  min_capacity       = var.service_params.desired_count
  resource_id        = "service/${var.existing_cluster_name}/${aws_ecs_service.service.name}"
  role_arn           = aws_iam_role.service_autoscaling_role[0].arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_scale_policy" {
  count = var.service_autoscaling.scale_on_cpu ? 1 : 0

  name               = "${var.service.name}-cpu-scale-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.service_autoscaling.cpu_threshold
    scale_in_cooldown  = var.service_autoscaling.scale_in_cooldown
    scale_out_cooldown = var.service_autoscaling.scale_out_cooldown

  }
}

resource "aws_appautoscaling_policy" "memory_scale_policy" {
  count = var.service_autoscaling.scale_on_memory ? 1 : 0

  name               = "${var.service.name}-memory-scale-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.service_autoscaling.memory_threshold
    scale_in_cooldown  = var.service_autoscaling.scale_in_cooldown
    scale_out_cooldown = var.service_autoscaling.scale_out_cooldown

  }
}
resource "aws_cloudwatch_metric_alarm" "service-alarm" {
  count               = try(var.trigger.lb, null) != null && var.alarm_topic_name != null ? 1 : 0
  alarm_name          = "${var.service.name}-lb-target-count-alarm"
  evaluation_periods  = "2"
  comparison_operator = "LessThanOrEqualToThreshold"
  threshold           = "0"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  treat_missing_data  = "missing"
  alarm_description   = "Load Balancer target count of ${var.service.name} is 0"
  alarm_actions       = [data.aws_sns_topic.system-alarm[count.index].arn]
  dimensions          = {
    TargetGroup  = aws_lb_target_group.service_tg[count.index].arn_suffix
    LoadBalancer = data.aws_lb.lb_trigger[0].arn_suffix
  }

}

