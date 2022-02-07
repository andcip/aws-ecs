terraform {
  experiments = [module_variable_optional_attrs]
}

variable "existing_cluster_name" {
  type = string
  description = "The existing ECS Cluster name."
}

variable "vpc_id" {
  type = string
  description = "Id of the VPC where ecs have to be."
}

variable "trigger" {
  type    = object({
    lb : object({
      name : string,
      rules : list(object({
        path_patterns : list(string)
        hosts : optional(list(string))
        http_headers : optional(list(map(string)))
        http_methods : optional(list(string))
        source_ips : optional(list(string))
        query_string : optional(string)
      }))
    })
  })
  default = null
  description = "The Service trigger, supported only alb right now. Default null."
}

variable "service_policies" {
  type = list(object({
    actions   = list(string)
    resources = list(string)
  }))

  default = []
  description = "List of all iam policy to attach to the service. Default empty."
}

variable "healthcheck" {
  type = object({
    port : number
    path : string
    ecs_enabled : bool
  })

  default = {
    port : 80, path : "/", ecs_enabled : false
  }
  description = "Service Healthcheck configuration. Default to root path on port 80 only from alb if present."
}

variable "service" {
  type = object({
    name : string
    version : string
    port : number
    capacity_provider : optional(list(object({
      provider : string
      weight : number
      base : optional(number)
    })))
    env : map(string)
  })

  description = "The service configuration parameters."
}

variable "service_registry_name" {
  type    = string
  default = null
  description = "Service registry name. If specified, it creates a private DNS for the service."
}

variable "service_params" {
  type        = object({
    cpu           = number,
    memory        = number,
    desired_count = number,
    is_public     = bool
  })
  default     = {
    cpu           = 512,
    memory        = 1024,
    desired_count = 1,
    is_public     = false
  }

  description = "Service deployment parameters. Default 512 cpu, 1024 memory and  1 private instance."
}

variable "service_autoscaling" {

  type        = object({
    max_instance_number = number
    scale_on_cpu        = bool
    scale_on_memory     = bool
    scale_on_schedule   = bool
    stop_schedule       = string
    start_schedule      = string
    cpu_threshold       = number
    memory_threshold    = number
    scale_out_cooldown  = number
    scale_in_cooldown   = number
  })
  default     = {
    max_instance_number = 1
    scale_on_cpu        = false
    scale_on_memory     = false
    scale_on_schedule   = false
    #https://docs.aws.amazon.com/autoscaling/application/userguide/examples-scheduled-actions.html#recurrence-schedule-cron
    start_schedule      = "cron(0 8 * * ? *)"
    stop_schedule       = "cron(0 20 * * ? *)"
    ##
    cpu_threshold       = 60
    memory_threshold    = 80
    scale_out_cooldown  = 60
    scale_in_cooldown   = 180
  }
  description = "Service autoscaling parameters with cpu, memory or schedule metrics. Default disabled"
}

variable "alarm_topic_name" {
  type    = string
  default = null
  description = "If specified, it enable error alarms to a specific sns topic. Default null."
}
