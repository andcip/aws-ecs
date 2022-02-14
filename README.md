# ECS SERVICE

## AWS ECS Service Module

--------------

This module deploy an ECS service, useful for Continuos Deployment


### Example of invocation

```
## Required filed to use an existing cluster
existing_cluster_name = dependency.application.outputs.cluster.name

vpc_id                = dependency.networking.outputs.vpc.id


service_policies = [
{
  actions = [
    "s3:ListBucket",
    "s3:GetObject",
    "s3:GetObjectAcl",
    "s3:PutObject",
    "s3:PutObjectAcl",
    "s3:ReplicateObject",
    "s3:DeleteObject"
  ]
  resources = [
    dependency.application.outputs.cms_assets_bucket.arn,
    "${dependency.application.outputs.cms_assets_bucket.arn}/*"
  ]
},
{
  actions = [
    "ses:SendEmail",
    "ses:SendRawEmail"
  ]
  resources = ["*"]
}
]

## Trigger input that specify service trigger, supported only ALB right now
trigger = {

lb : {
  name : dependency.application.outputs.alb.name
  rules : [
    {
      path_patterns = ["/*"]
      hosts = ["cms.assistdigital.it"]
    }
  ]
}
}

healthcheck = {
  port = 8055
  path : "/server/ping"
  ecs_enabled : false
}

service = {
name              = "cms"
version           = get_env("IMAGE_VERSION", "null")
port              = 8055
capacity_provider = [
  {
    provider = "FARGATE_SPOT"
    base     = 1
    weight   = 1
  },
  {
    provider = "FARGATE"
    base = 0
    weight = 1
  }
]

```

------------

# Variable Documentation


<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.cpu_scale_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.memory_scale_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_scheduled_action.turn_off_scheduled_action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_scheduled_action) | resource |
| [aws_appautoscaling_scheduled_action.turn_on_scheduled_action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_scheduled_action) | resource |
| [aws_appautoscaling_target.ecs_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.service_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.task_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.service-alarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.service_task_definition](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.service_autoscaling_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.function_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.task_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.service_autoscaling_role_policy_attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task_execution_role_attach](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb_listener_rule.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.service_tg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_security_group.service_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_service_discovery_service.ecs_discovery_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_ecr_repository.service_repository](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_repository) | data source |
| [aws_iam_policy.aws_service_autoscale_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_iam_policy.task_execution_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy) | data source |
| [aws_lb.lb_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_lb_listener.lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_listener) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_service_discovery_dns_namespace.service_registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/service_discovery_dns_namespace) | data source |
| [aws_sns_topic.system-alarm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/sns_topic) | data source |
| [aws_subnets.subnets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_topic_name"></a> [alarm\_topic\_name](#input\_alarm\_topic\_name) | If specified, it enable error alarms to a specific sns topic. Default null. | `string` | `null` | no |
| <a name="input_existing_cluster_name"></a> [existing\_cluster\_name](#input\_existing\_cluster\_name) | The existing ECS Cluster name. | `string` | n/a | yes |
| <a name="input_healthcheck"></a> [healthcheck](#input\_healthcheck) | Service Healthcheck configuration. Default to root path on port 80 only from alb if present. | <pre>object({<br>    port : number<br>    path : string<br>    ecs_enabled : bool<br>  })</pre> | <pre>{<br>  "ecs_enabled": false,<br>  "path": "/",<br>  "port": 80<br>}</pre> | no |
| <a name="input_service"></a> [service](#input\_service) | The service configuration parameters. | <pre>object({<br>    name : string<br>    version : string<br>    port : number<br>    capacity_provider : optional(list(object({<br>      provider : string<br>      weight : number<br>      base : optional(number)<br>    })))<br>    env : map(string)<br>  })</pre> | n/a | yes |
| <a name="input_service_autoscaling"></a> [service\_autoscaling](#input\_service\_autoscaling) | Service autoscaling parameters with cpu, memory or schedule metrics. Default disabled | <pre>object({<br>    max_instance_number = number<br>    scale_on_cpu        = bool<br>    scale_on_memory     = bool<br>    scale_on_schedule   = bool<br>    stop_schedule       = string<br>    start_schedule      = string<br>    cpu_threshold       = number<br>    memory_threshold    = number<br>    scale_out_cooldown  = number<br>    scale_in_cooldown   = number<br>  })</pre> | <pre>{<br>  "cpu_threshold": 60,<br>  "max_instance_number": 1,<br>  "memory_threshold": 80,<br>  "scale_in_cooldown": 180,<br>  "scale_on_cpu": false,<br>  "scale_on_memory": false,<br>  "scale_on_schedule": false,<br>  "scale_out_cooldown": 60,<br>  "start_schedule": "cron(0 8 * * ? *)",<br>  "stop_schedule": "cron(0 20 * * ? *)"<br>}</pre> | no |
| <a name="input_service_params"></a> [service\_params](#input\_service\_params) | Service deployment parameters. Default 512 cpu, 1024 memory and  1 private instance. | <pre>object({<br>    cpu           = number,<br>    memory        = number,<br>    desired_count = number,<br>    is_public     = bool<br>  })</pre> | <pre>{<br>  "cpu": 512,<br>  "desired_count": 1,<br>  "is_public": false,<br>  "memory": 1024<br>}</pre> | no |
| <a name="input_service_policies"></a> [service\_policies](#input\_service\_policies) | List of all iam policy to attach to the service. Default empty. | <pre>list(object({<br>    actions   = list(string)<br>    resources = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_service_registry_name"></a> [service\_registry\_name](#input\_service\_registry\_name) | Service registry name. If specified, it creates a private DNS for the service. | `string` | `null` | no |
| <a name="input_trigger"></a> [trigger](#input\_trigger) | The Service trigger, supported only alb right now. Default null. | <pre>object({<br>    lb : object({<br>      name : string,<br>      rules : list(object({<br>        path_patterns : list(string)<br>        hosts : optional(list(string))<br>        http_headers : optional(list(map(string)))<br>        http_methods : optional(list(string))<br>        source_ips : optional(list(string))<br>        query_string : optional(string)<br>      }))<br>    })<br>  })</pre> | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Id of the VPC where ecs have to be. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ecs_service"></a> [ecs\_service](#output\_ecs\_service) | n/a |
<!-- END_TF_DOCS -->
