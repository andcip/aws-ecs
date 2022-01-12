terraform {
  experiments = [module_variable_optional_attrs]
}

variable "existing_cluster_name" {
  type    = string
}

variable "vpc_id" {
  type = string
}

variable "trigger" {
  type    = object({
    lb: object({
      name: string,
      conditions: object({
        path_patterns: list(string)
        hosts: optional(list(string))
        http_headers: optional(list(map(string)))
        http_methods: optional(list(string))
        source_ips: optional(list(string))
        query_string: optional(string)
      })
    })
  })
  default = null
}

variable "service_policies" {
  type = list(object({
    actions = list(string)
    resources = list(string)
  }))

  default = []
}

variable "healthcheck" {
  type =  object({
    port: number
    path: string
    ecs_enabled: bool
  })

  default = {
    port: 80, path: "/", ecs_enabled: false
  }
}

variable "service" {
  type = object({
    name : string
    version : string
    port : number
    capacity_provider: object({
      provider: string
      base: number,
      weight: number
    })
    env: map(string)
  })
}

variable "service_registry_name" {
  type = string
  default = null
}

variable "service_params" {
  description = "Service deployment parameters"
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
}

variable "service_autoscaling" {
  description = "Service autoscaling parameters"
  type        = object({
    max_instance_number = number,
    scale_on_cpu        = bool,
    scale_on_memory     = bool,
    cpu_threshold       = number,
    memory_threshold    = number,
    scale_out_cooldown  = number,
    scale_in_cooldown   = number
  })
  default     = {
    max_instance_number = 1,
    scale_on_cpu        = false,
    scale_on_memory     = false,
    cpu_threshold       = 60,
    memory_threshold    = 80,
    scale_out_cooldown  = 60,
    scale_in_cooldown   = 180
  }
}

variable "alarm_topic_name" {
  type    = string
  default = null
}
