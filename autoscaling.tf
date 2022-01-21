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

resource "aws_appautoscaling_scheduled_action" "turn_on_scheduled_action" {
  count              = var.service_autoscaling.scale_on_schedule ? 1 : 0
  name               = "turn_on_action"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  schedule           = var.service_autoscaling.start_schedule

  scalable_target_action {
    min_capacity = var.service_params.desired_count
    max_capacity = var.service_autoscaling.max_instance_number
  }
}

resource "aws_appautoscaling_scheduled_action" "turn_off_scheduled_action" {
  count              = var.service_autoscaling.scale_on_schedule ? 1 : 0
  name               = "turn_off_action"
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  schedule           = var.service_autoscaling.stop_schedule

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}
