provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-dev-calicot-team3"
  location = var.location
}

# Création du Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-dev-calicot-cc-${var.code_identification}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
}

# Sous-réseau pour l'application web
resource "azurerm_subnet" "snet_web" {
  name                 = "snet-dev-web-cc-${var.code_identification}"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.snet_web_address_prefix
}

# Sous-réseau sécurisé pour la base de données
resource "azurerm_subnet" "snet_db" {
  name                 = "snet-dev-db-cc-${var.code_identification}"
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.snet_db_address_prefix
}

# Création d'un groupe de sécurité pour autoriser HTTP et HTTPS sur le sous-réseau Web
resource "azurerm_network_security_group" "nsg_web" {
  name                = "nsg-dev-web-cc-${var.code_identification}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Règle pour autoriser HTTP
resource "azurerm_network_security_rule" "allow_http" {
  name                        = "Allow-HTTP"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_web.name
}

# Règle pour autoriser HTTPS
resource "azurerm_network_security_rule" "allow_https" {
  name                        = "Allow-HTTPS"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_web.name
}

# Association du NSG au sous-réseau Web
resource "azurerm_subnet_network_security_group_association" "web_nsg_association" {
  subnet_id                 = azurerm_subnet.snet_web.id
  network_security_group_id = azurerm_network_security_group.nsg_web.id
}

resource "azurerm_service_plan" "app_service_plan" {
  name                = "plan-calicot-dev-${var.code_identification}"
  location            = "Canada Central"
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"  
  sku_name            = "S1"    
}


resource "azurerm_key_vault" "kv" {
  name                = "kv-calicot-dev-${var.code_identification}"
  location            = "Canada Central"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "standard"
  tenant_id           = var.tenant_id

  // Access policy for the web app's managed identity
  access_policy {
    tenant_id = var.tenant_id
    object_id = azurerm_app_service.app_service.identity[0].principal_id
    secret_permissions = ["Get", "List"]
  }
}

resource "azurerm_app_service" "app_service" {
  name                = "app-calicot-dev-${var.code_identification}"
  location            = "Canada Central"
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_service_plan.app_service_plan.id

  // HTTPS uniquement
  https_only = true

  // Configuration de l'identité managée assignée par le système
  identity {
    type = "SystemAssigned"
  }

  // Paramètres de l'application
  app_settings = {
    "ImageUrl" = "https://stcalicotprod000.blob.core.windows.net/images/"
  }

  // Always On activé ici
  site_config {
    always_on = true
  }

  connection_string {
    name  = "ConnectionStrings"
    type  = "Custom"
    value = "@Microsoft.KeyVault(SecretUri=https://kv-calicot-dev-${var.code_identification}.vault.azure.net/secrets/ConnectionStrings)"
  }
}

// ... existing code ...

resource "azurerm_monitor_autoscale_setting" "example" {
  name                = "autoscale-calicot-dev-${var.code_identification}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "Canada Central"
  target_resource_id  = azurerm_service_plan.app_service_plan.id

  profile {
    name = "defaultProfile"
    capacity {
      default = 1
      minimum = 1
      maximum = 3
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.app_service_plan.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 75
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.app_service_plan.id
        operator           = "LessThan"
        statistic          = "Average"
        threshold          = 25
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}

resource "azurerm_mssql_server" "sqlsrv" {
  name                         = "sqlsrv-calicot-dev-${var.code_identification}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = "Canada Central"
  version                      = "12.0"
  administrator_login          = "damienc"  # Replace with your desired login
  administrator_login_password = "Team3Pass#_3566"  # Replace with your desired password
}

# Corrected azurerm_mssql_database configuration
resource "azurerm_mssql_database" "sqldb" {
  name     = "sqldb-calicot-dev-${var.code_identification}"
  server_id = azurerm_mssql_server.sqlsrv.id
  sku_name = "Basic"
}