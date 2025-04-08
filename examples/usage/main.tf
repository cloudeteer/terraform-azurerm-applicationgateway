terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.108.0"
    }
  }
}
resource "azurerm_resource_group" "example" {
  name     = "rg-example-dev-we-01"
  location = "West Europe"
}

data "azurerm_client_config" "current" {}

resource "azurerm_virtual_network" "example" {
  name                = "vnet-example-dev-we-01"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                = "snet-example-dev-we-01"
  resource_group_name = azurerm_resource_group.example.name

  address_prefixes = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.example.name
}

resource "azurerm_web_application_firewall_policy" "example-url-policy" {
  name                = "example-waf-policy"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location

  policy_settings {
    enabled                          = true
    file_upload_limit_in_mb          = 5
    max_request_body_size_in_kb      = 128
    mode                             = "Prevention"
    request_body_check               = false
    request_body_inspect_limit_in_kb = 128
  }

  custom_rules {
    action    = "Block"
    name      = "BlockGeoLocation"
    priority  = 10
    rule_type = "MatchRule"

    match_conditions {
      match_values = [
        "CN",
        "RU",
        "BY",
        "UA",
      ]
      negation_condition = false
      operator           = "GeoMatch"
      transforms = []

      match_variables {
        variable_name = "RemoteAddr"
      }
    }
  }
}

//TODO: Soll eine IP im Module schon erstellt werden? --> Soll im Module erstellt werden
resource "azurerm_public_ip" "exmaple-public-ip" {
  allocation_method   = "Dynamic"
  location            = azurerm_resource_group.example.location
  name                = "examaple-public-ip"
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_key_vault" "example-keyvault" {
  location            = azurerm_resource_group.example.location
  name                = "example-keyvault"
  resource_group_name = azurerm_resource_group.example.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
}

//Optional
resource "azurerm_key_vault_certificate" "example-ssl" {

  name         = "example-ssl"
  key_vault_id = azurerm_key_vault.example-keyvault.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # Server Authentication = 1.3.6.1.5.5.7.3.1
      # Client Authentication = 1.3.6.1.5.5.7.3.2
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=${azurerm_public_ip.exmaple-public-ip.ip_address}"
      validity_in_months = 3
    }
  }
}


################################
## Module Application Gateway ##
################################
# TODO#1: Error Page?  --> Optional
# TODO#2: WAF Rules "nur" URL spezifisch oder "global" anwenden, da man an ein APP-Gateway
# TODO#3: Wir bieten NUR HTTPS an, HTTP wird nur an HTTPS weitergeleitet
# TODO#4: Priorität bei den Request-rules?
#noinspection TfUnknownProperty
module "example" {
  # Change "module" and "provider" accordingly to match you new module
  source = "cloudeteer/module/provider"

  name                = "example-name"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  tags = "example"

  ##Optional##
  autoscaling_capacity = {
    min_capacity = 1
    max_capacity = 2
  }

  #DEFAULT
  public_ip = {
    enable            = true
    sku               = "Standard"
    allocation_method = "Static"
    ip_version        = "IPv4"
  }


  # TODO: private IP SOLLTE eine Static private IP sein.
  # Optional
  private_ip = {
    ip_address        = "10.11.1.10"
    allocation_method = "Static"
    subnet_id         = azurerm_subnet.example.id
  }

  # TODO: Wir redirect von 80 zu 443
  //Default
  frontend_ports = [
    {
      name = "http"
      port = 80
    },
    {
      name = "https"
      port = 443
    }
  ]



  domains = [
    {
      #Listener
      host = "example-one.de" #required
      name = "Shop" # optional
      ssl_certificate_id = azurerm_key_vault_certificate.example-ssl.versionless_secret_id //Default
      # private frontend
      enable_private     = false // Default --> Gedanken zu machen // Firewall soll eine andere sein/keine sein
      #Firewall
      firewall_policy_id = azurerm_web_application_firewall_policy.example-url-policy.id //Optional
      http_port = 80 // Default
      pathing_rule = [
        {
          #Path-based-rule
          path = "/*"  # Default
          name = "shoppidishop" //optional
          #Backendpool config
          backend_ips = ["10.11.3.100"] // Required
          #ProbeChecker
          probe_protocol = "Http"   // Default
          probe_path = "/"      // Default
          probe_timeout = 30       // Default
          probe_unhealthy_threshold = 3        // Default
          probe_status_code = ["200-399"]  //Default

        },
        {
          path           = "/admin/"
          name           = "keycloak"
          backend_ips = ["10.11.3.100"] // Required
          http_port = 80 // Default
          probe_protocol = "Http"   // Default
          probe_path = "/"      // Default
          probe_timeout = 30       // Default
          probe_unhealthy_threshold = 3        // Default
          probe_status_code = ["200-399"]  //Default
          enable_private = false // Default --> Gedanken zu machen
        }

      ]
    },
    {
      #Listener
      host = "example-two.de" #required
      name = "Shop" # optional
      ssl_certificate_id = azurerm_key_vault_certificate.example-ssl.versionless_secret_id //Default
      # private frontend
      enable_private     = false // Default --> Gedanken zu machen // Firewall soll eine andere sein/keine sein
      #Firewall
      firewall_policy_id = azurerm_web_application_firewall_policy.example-url-policy.id //Optional
      http_port = 80 // Default
      pathing_rule = [
        {
          #Path-based-rule
          path = "/*"  # Default
          name = "shoppidishop" //optional
          #Backendpool config
          backend_ips = ["10.11.3.100"] // Required
          #ProbeChecker
          probe_protocol = "Http"   // Default
          probe_path = "/"      // Default
          probe_timeout = 30       // Default
          probe_unhealthy_threshold = 3        // Default
          probe_status_code = ["200-399"]  //Default

        }
      ]
    }
  ]

  # Diagnostic Settings
  # TODO: Hier

  # User assigned identity
  # TODO: Auf Roman zugehen --> bei EEW mal anschauen
}
