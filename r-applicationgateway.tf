locals {

}

resource "azurerm_application_gateway" "this" {
  name                = var.app_gateway_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    # TODO: Müssen beide gleich bleiben?!
    name     = var.sku_tier
    tier     = var.sku_tier
    capacity = var.sku_capacity
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = var.virtual_subnet_id
  }

  frontend_port {
    name = "FrontEnd"
    port = var.frontend_port
  }

  frontend_ip_configuration {
    name                 = "FrontEnd-IpConfiguration"
    public_ip_address_id = var.public_ip_address_id != "" ? azurerm_public_ip.this.id : var.public_ip_address_id
  }

  dynamic "backend_address_pool" {
    for_each = {for idx, domain in var.domains : idx => domain}
    content {
      name         = backend_address_pool.value.name
      ip_addresses = each.domain.
    }
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}