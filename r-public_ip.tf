resource "azurerm_public_ip" "this" {
  count               = var.public_ip_address_id!= "" ? 0 : 1
  allocation_method   = "Dynamic"
  location            = var.location
  name                = "${var.name}-public-ip"
  resource_group_name = var.resource_group_name
}