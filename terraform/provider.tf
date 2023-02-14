terraform {
  required_version = ">=1.2"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.40"
    }
  }
  backend "azurerm" {
    resource_group_name  = "terraform-rg"
    storage_account_name = "jwalterstfstorage202302"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    #    use_oidc = true
  }
}

provider "azurerm" {
  #  use_oidc = true
  features {}
}