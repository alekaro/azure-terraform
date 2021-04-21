########################################################################
# VARIABLES
########################################################################

variable "prefix" {
    type    = string
    default = "rs"
}

variable "resource_group_name" {
    type    = string
    default = "vmss-rs-rg"
}

variable "location" {
    type    = string
    default = "westeurope"
}

########################################################################
# PROVIDERS
########################################################################

provider "azurerm" {
    features {}
}

########################################################################
# RESOURCES
########################################################################

resource "azurerm_resource_group" "main" {
    name     = var.resource_group_name
    location = var.location
}

resource "random_integer" "sa_id" {
  min = 10000
  max = 99999
}

resource "azurerm_storage_account" "main" {
  name                     = "${var.prefix}${random_integer.sa_id.result}sa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_storage_container" "main" {
  name                  = "state-container"
  storage_account_name  = azurerm_storage_account.main.name
}

data "azurerm_storage_account_sas" "state" {
    connection_string = azurerm_storage_account.main.primary_connection_string
    https_only        = true

    resource_types {
        service     = true
        container   = true
        object      = true
    }

    services {
        blob    = true
        queue   = false
        table   = false
        file    = false
    }

    start   = timestamp()
    expiry  = timeadd(timestamp(), "48h")

    permissions {
        read    = true
        write   = true
        delete  = true
        list    = true
        add     = true
        create  = true
        update  = false
        process = false
    }
}

########################################################################
# OUTPUTS
########################################################################

output "storage_account_id" {
    value = azurerm_storage_account.main.id
}

output "storage_account_name" {
    value = azurerm_storage_account.main.name
}

output "storage_container_name" {
    value = azurerm_storage_container.main.name
}

resource "null_resource" "post-config" {

  depends_on = [azurerm_storage_container.main]

  provisioner "local-exec" {
    command = <<EOT
echo 'storage_account_name = "${azurerm_storage_account.main.name}"' > backend-config.txt
echo 'container_name = "${azurerm_storage_container.main.name}"' >> backend-config.txt
echo 'key = "terraform.tfstate"' >> backend-config.txt
echo 'sas_token = "${data.azurerm_storage_account_sas.state.sas}"' >> backend-config.txt
EOT
  }
}