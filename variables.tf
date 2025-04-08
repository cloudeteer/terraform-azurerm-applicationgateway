variable "example_variable" {
  description = "Example variable (between 3 and 13 characters)"
  type        = string

  validation {
    condition     = length(var.example_variable) >= 3 && length(var.example_variable) <= 99
    error_message = "Example variable must be between 3 and 99 characters"
  }
}

variable "sku_tier" {
  type        = string
  description = "(Required) Sets SKU of teh Application-Gateway. Possible values are Basic, Standard and Premium. Defaults to Basic. Please consider different functionalities of each SKU, for more information: https://learn.microsoft.com/en-gb/azure/application-gateway/overview-v2#sku-types"
  default     = "Standard_v2"
}

variable "app_gateway_name" {
  type        = string
  description = "Name of the Application Gateway."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group in which to create the Application Gateway."
}

variable "virtual_subnet_id" {
  type        = string
  description = "Virtual network's which should be used. Changing this forces a new resource to be created."
}

variable "location" {
  type        = string
  description = "Location of the Application Gateway."
}

variable "frontend_port" {
  type        = string
  description = "Set the Frontend port of this Gateway."
  default     = "80"
}

variable "backend_settings" {}

variable "public_ip_address_id" {
  type        = string
  description = "Optional globally unique within the Azure Virtual Network."
}

// TODO: Test Schreiben, da basic nur 2 haben darf und Standardv2 bis 128 haben kann --> sollte mit auto_scaling getestet werden
variable "sku_capacity" {
  type        = number
  description = "(Optional) The Capacity of the SKU to use for this Application Gateway. When using a V1 SKU this value must be between 1 and 32, and 1 to 125 for a V2 SKU. When using a Basic SKU this property must be between 1 and 2. This property is optional if autoscale_configuration is set."
  default     = 2
}

variable "domains" {
  type = list(object({
    host               = string
    name = string # optional
    ssl_certificate_id = string
    enable_private = bool   # optional
    firewall_policy_id = string # optional
    http_port = number # optional
    pathing_rule = list(object({
      path      = string
      name = string # optional
      backend_ips = list(string)
      probe_protocol = string # optional
      probe_path = string # optional
      probe_timeout = number # optional
      probe_unhealthy_threshold = number # optional
      probe_status_code = list(string) # optional
      enable_private = bool   # optional
      http_port = number # optional
    }))
  }))
  description = "See Example at www.internet.de"
}

