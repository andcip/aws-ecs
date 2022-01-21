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

  assume_role_policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Action : "sts:AssumeRole"
        Effect : "Allow"
        Principal : {
          Service : "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  tags               = {
    Name = "${var.service.name}-task-role"
  }
}

resource "aws_iam_role_policy" "task_role_policy" {
  name = "${var.service.name}-task-policy"
  role = aws_iam_role.task_role.id

  policy = jsonencode({

    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow"
        Action : [
          "xray:PutTelemetryRecords",
          "xray:PutTraceSegments"
        ]
        Resource : "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "function_policy" {
  count  = length(var.service_policies)
  name   = "${var.service.name}_function_policy_${count.index}"
  role   = aws_iam_role.task_role.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = var.service_policies[count.index].actions
        Resource = var.service_policies[count.index].resources
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

  healthcheck_command = var.healthcheck.ecs_enabled ? "curl -f http://localhost:${var.healthcheck.port}${var.healthcheck.path} || exit 1" : "exit 0"
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
        command  = ["CMD-SHELL", local.healthcheck_command]
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

data "aws_vpc" "vpc" {
  id = var.vpc_id
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

resource "aws_security_group" "service_sg" {
  name   = "${var.service.name}-service-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.service.port
    to_port         = var.service.port
    security_groups = var.trigger.lb != null ? data.aws_lb.lb_trigger[0].security_groups : null
    cidr_blocks     = var.trigger.lb != null ? null : [data.aws_vpc.vpc.cidr_block]
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
    subnets          = data.aws_subnets.subnets.ids
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

}

resource "aws_cloudwatch_log_group" "service_log_group" {
  depends_on        = [aws_ecs_service.service]
  name              = "/ecs/${var.service.name}"
  retention_in_days = 90
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

