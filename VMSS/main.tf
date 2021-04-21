########################################################################
# VARIABLES
########################################################################

variable "prefix" {
    type    = string
    default = "vmss"
}

variable "resource_group_name" {
    type    = string
    default = "vmss-rg"
}

variable "location" {
    type    = string
    default = "westeurope"
}

variable "vnet_cidr_range" {
    type    = list(string)
    default = ["10.0.0.0/16"]
}

variable "subnet_prefixes" {
    type    = list(string)
    default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "subnet_names" {
    type    = list(string)
    default = ["web", "gateway"]
}

########################################################################
# PROVIDERS
########################################################################

provider "azurerm" {
    features {}
}

########################################################################
# DATA
########################################################################

data "template_file" "linux-vm-cloud-init" {
  template = file("azure-user-data.sh")
  vars = {
    storage_account_name    = data.terraform_remote_state.state.outputs.storage_account_name
    storage_container_name  = data.terraform_remote_state.state.outputs.storage_container_name
  }
}

data "terraform_remote_state" "state" {
  backend = "azurerm"
  config = {
    storage_account_name    = "rs62598sa"
    container_name          = "state-container"
    key                     = "terraform.tfstate"
    sas_token               = "?sv=2017-07-29&ss=b&srt=sco&sp=rwdlac&se=2021-04-23T11:22:50Z&st=2021-04-21T11:22:50Z&spr=https&sig=NIHDCBCKMwr4tCX0Fhqz65Ru1c2J%2B77RxE9ccfzdbO8%3D"
  }
}

########################################################################
# RESOURCES
########################################################################

# resource "azurerm_resource_group" "main" {
#     name     = var.resource_group_name
#     location = var.location
# }

# ---------- Creating VNET resources -----------------------
module "vnet-main" {
    source                  = "Azure/vnet/azurerm"
    resource_group_name     = var.resource_group_name
    vnet_name               = "${var.resource_group_name}-vnet"
    address_space           = var.vnet_cidr_range
    subnet_prefixes         = var.subnet_prefixes
    subnet_names            = var.subnet_names
    nsg_ids                 = {}

    tags = {
        environment = "dev"
        costcenter  = "it"
    }

    # depends_on = [azurerm_resource_group.main]
}

resource "azurerm_public_ip" "main" {
  name                = "${var.prefix}-pubip"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Dynamic"
}

# resource "azurerm_network_interface" "main" {
#   name                = "${var.prefix}-nic"
#   location            = var.location
#   resource_group_name = var.resource_group_name

#   ip_configuration {
#     name                          = "testconfiguration1"
#     subnet_id                     = module.vnet-main.vnet_subnets[0]
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.main.id
#   }
# }

# --------- Creating Load Balancer and Healt Probe for VMSS -----
# resource "azurerm_public_ip" "ip_1" {
#   name                = "public_ip_for_lb"
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   allocation_method   = "Static"
# }

# resource "azurerm_lb" "main" {
#   name                = "test_load_balancer"
#   location            = var.location
#   resource_group_name = var.resource_group_name

#   frontend_ip_configuration {
#     name                 = "public_ip_address"
#     public_ip_address_id = azurerm_public_ip.ip_1.id
#   }
# }

# resource "azurerm_lb_probe" "main" {
#   resource_group_name = var.resource_group_name
#   loadbalancer_id     = azurerm_lb.main.id
#   name                = "ssh-running-probe"
#   port                = 22
# }

#------------------- Creating Application Gateway ----------------
locals {
  backend_address_pool_name      = "${module.vnet-main.vnet_name}-beap"
  frontend_port_name             = "${module.vnet-main.vnet_name}-feport"
  frontend_ip_configuration_name = "${module.vnet-main.vnet_name}-feip"
  http_setting_name              = "${module.vnet-main.vnet_name}-be-htst"
  listener_name                  = "${module.vnet-main.vnet_name}-httplstn"
  request_routing_rule_name      = "${module.vnet-main.vnet_name}-rqrt"
  redirect_configuration_name    = "${module.vnet-main.vnet_name}-rdrcfg"
}

resource "azurerm_public_ip" "ip_2" {
  name                = "public_ip_for_gw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

resource "azurerm_application_gateway" "network" {
  name                = "${var.prefix}-gw"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = module.vnet-main.vnet_subnets[1]
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.ip_2.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    # path                  = "/path1/"
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
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

# ------------------ Creating Linux VM Scale Set -----------------
resource "azurerm_linux_virtual_machine_scale_set" "main" {
  name                  = "${var.prefix}-vmss"
  location              = var.location
  resource_group_name   = var.resource_group_name
  sku                   = "Standard_B2s"
  admin_username        = "adminuser"
  instances             = 1
  upgrade_mode          = "Automatic"
  # health_probe_id       = azurerm_lb_probe.main.id
  # vm_size               = "Standard_B2s" #1ls"

  # !!! custom_data is responsible for executing initialization script (kind of instance template) !!
  # https://gmusumeci.medium.com/how-to-bootstrapping-azure-vms-with-terraform-c8fdaa457836
  custom_data    = base64encode(data.template_file.linux-vm-cloud-init.rendered)

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "example"
    primary = true

    ip_configuration {
      name          = "internal"
      primary       = true
      subnet_id     = module.vnet-main.vnet_subnets[0]
      application_gateway_backend_address_pool_ids = azurerm_application_gateway.network.backend_address_pool[*].id
    }
  }

  identity {
    type        = "SystemAssigned"
  }
}

resource "azurerm_monitor_autoscale_setting" "rules" {
  name                = "${var.prefix}-scale-settings"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.main.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 3
    }

    rule {
      metric_trigger {
        metric_name        = "Requests per minute per Healthy Host"
        metric_resource_id = azurerm_application_gateway.network.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT1M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 2
        metric_namespace   = "Application gateway standard metrics"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Requests per minute per Healthy Host"
        metric_resource_id = azurerm_application_gateway.network.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT1M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 1
        metric_namespace   = "Application gateway standard metrics"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}

# Application gateway metrics:
#   "CPU Utilization"
#   "Current Connections"
#   "Failed Requests"
#   "Healthy Host Count"
#   "Requests per minute per Healthy Host"
#   "Response Status"
#   "Throughput"
#   "Total Requests"
#   "Unhealthy Host Count"


########################################################################
# ROLE DEFINITIONS
########################################################################

resource "azurerm_role_definition" "vm_to_sa_rd" {
    name                = "test_role_definition"
    scope               = data.terraform_remote_state.state.outputs.storage_account_id

    permissions {
        actions         = ["*"]
        data_actions    = ["*"]
        not_actions     = []
  }
}

########################################################################
# ROLE ASSIGNMENTS
########################################################################

resource "azurerm_role_assignment" "vm_to_sa_ra" {
    scope               = data.terraform_remote_state.state.outputs.storage_account_id
    role_definition_id  = azurerm_role_definition.vm_to_sa_rd.role_definition_resource_id
    principal_id        = azurerm_linux_virtual_machine_scale_set.main.identity[0].principal_id
}

########################################################################
# OUTPUTS
########################################################################

output "vnet_id" {
    value = module.vnet-main.vnet_id
}

# tutorial to connect to Storage Account from Linux VM using MI (Managed Identity):
# https://docs.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/tutorial-linux-vm-access-storage

# Other useful tutorials
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/managed_service_identity

# examples
# https://github.com/ned1313/Implementing-Terraform-on-Microsoft-Azure/blob/master/4-remote-state-prep/main.tf
