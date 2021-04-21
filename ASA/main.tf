terraform {
    backend "azurerm" {
        # resource_group_name     = "vmss-rs-rg"
        storage_account_name    = "rs47704sa"
        container_name          = "state-container"
        key                     = "terraform.tfstate"

        sas_token               = "?sv=2017-07-29&ss=b&srt=sco&sp=rwdlac&se=2021-04-23T08:32:23Z&st=2021-04-21T08:32:23Z&spr=https&sig=NmaV%2BjXuv3oiv0KYiPu2VpINX9mRrtnO%2Bb%2BDc27bMwE%3D"
        # use_msi                 = true

        # subscription_id         = "882c09dc-5677-4228-82e4-8bb80de844cd"
        # tenant_id               = "28c1267c-2e2c-47a2-af95-7830aa7f6d39"
    }
}

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

# variable "output_file" {
#     type    = string
#     default = "storage_details"
# }

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
  name                  = "${var.prefix}${random_integer.sa_id.result}ct"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
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


# resource "null_resource" "post-config" {

#   depends_on = [azurerm_storage_container.main]

#   provisioner "local-exec" {
#     command = <<EOT
# echo 'variable "storage_account_id" {' > ${var.output_file}.tf
# echo '  type    = string' >> ${var.output_file}.tf
# echo '  default = "${azurerm_storage_account.main.id}"' >> ${var.output_file}.tf
# echo '}' >> ${var.output_file}.tf
# echo 'variable "storage_account_name" {' >> ${var.output_file}
# echo '  type    = string' >> ${var.output_file}.tf
# echo '  default = "${azurerm_storage_account.main.name}"' >> ${var.output_file}.tf
# echo '}' >> ${var.output_file}.tf
# echo 'variable "storage_container_name" {' >> ${var.output_file}
# echo '  type    = string' >> ${var.output_file}.tf
# echo '  default = "${azurerm_storage_container.main.name}"' >> ${var.output_file}.tf
# echo '}' >> ${var.output_file}.tf

# echo 'storage_account_id="${azurerm_storage_account.main.id}"' > ${var.output_file}.txt
# echo 'storage_account_name="${azurerm_storage_account.main.name}"' >> ${var.output_file}.txt
# echo 'storage_container_name="${azurerm_storage_container.main.name}"' >> ${var.output_file}.txt
# EOT
#   }
# }

# curl https://testvm86773sa.blob.core.windows.net/testvm86773ct/test.txt -H " eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6Im5PbzNaRHJPRFhFSzFqS1doWHNsSFJfS1hFZyIsImtpZCI6Im5PbzNaRHJPRFhFSzFqS1doWHNsSFJfS1hFZyJ9.eyJhdWQiOiJodHRwczovL3N0b3JhZ2UuYXp1cmUuY29tLyIsImlzcyI6Imh0dHBzOi8vc3RzLndpbmRvd3MubmV0LzI4YzEyNjdjLTJlMmMtNDdhMi1hZjk1LTc4MzBhYTdmNmQzOS8iLCJpYXQiOjE2MTg1MDE1NTQsIm5iZiI6MTYxODUwMTU1NCwiZXhwIjoxNjE4NTg4MjU0LCJhaW8iOiJFMlpnWURobVBVWEJKTmlIdGUyMnpKMklwMldsQUE9PSIsImFwcGlkIjoiMTUyYTdmMjktZDMzMS00NjAwLWI5MmYtNzQ5NTgwMTM0MjJmIiwiYXBwaWRhY3IiOiIyIiwiaWRwIjoiaHR0cHM6Ly9zdHMud2luZG93cy5uZXQvMjhjMTI2N2MtMmUyYy00N2EyLWFmOTUtNzgzMGFhN2Y2ZDM5LyIsIm9pZCI6ImU0ZjBlODUyLTA3ZTYtNDVjNC1hNmZmLWZmYmYzZTQ4NDMyZSIsInJoIjoiMC5BWUlBZkNiQktDd3Vva2V2bFhnd3FuOXRPU2xfS2hVeDB3Qkd1UzkwbFlBVFFpLUNBQUEuIiwic3ViIjoiZTRmMGU4NTItMDdlNi00NWM0LWE2ZmYtZmZiZjNlNDg0MzJlIiwidGlkIjoiMjhjMTI2N2MtMmUyYy00N2EyLWFmOTUtNzgzMGFhN2Y2ZDM5IiwidXRpIjoiR2t6SEgxcEs2RUtucDdac25Sd0pBQSIsInZlciI6IjEuMCIsInhtc19taXJpZCI6Ii9zdWJzY3JpcHRpb25zLzg4MmMwOWRjLTU2NzctNDIyOC04MmU0LThiYjgwZGU4NDRjZC9yZXNvdXJjZWdyb3Vwcy9zaW5nbGUtdm0tcmcvcHJvdmlkZXJzL01pY3Jvc29mdC5Db21wdXRlL3ZpcnR1YWxNYWNoaW5lcy90ZXN0dm0tdm0ifQ.P8FurCo-_NUNtWr5ZaeGnf8Drpaf0diXheTho-Pa1gWEEr2imJL2WPZbsH3Qon-9ErxBmB8ZiCrldjlTGMsFH1wkGbJ3pOP35I0vfrgKzWTItuXYaRfxtnvMTPdYNx3z37Y6tKfGI0tbdXLTiAsEKL2I8qdeSmoKJ8hpiqatwLF8jfFzQssNX8Y6JRpYsAq5RHpwYkivs4G_vewVyRxZAIhs4Z0U0rIVMspMBU1_ldwCGOeA0qaFg2mk7QrihIxZqBH3pAM0u6sdSpzIQgQq1ubGHSuwshrzUy1cTaigQSRprqFYdzkXU7sYt36zry3VQzvOQ7o8lVIEOQkBQJX06Q"