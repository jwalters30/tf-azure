# You can use the azurerm_client_config data resource to dynamically
# extract connection settings from the provider configuration.

data "azurerm_client_config" "core" {}

# Call the caf-enterprise-scale module directly from the Terraform Registry
# pinning to the latest version
module "enterprise_scale" {
  source  = "Azure/caf-enterprise-scale/azurerm"
  version = "3.1.2"
  providers = {
    azurerm              = azurerm
    azurerm.connectivity = azurerm
    azurerm.management   = azurerm
  }

  # Base module configuration settings
  root_parent_id = data.azurerm_client_config.core.tenant_id
  root_id        = var.root_id
  root_name      = var.root_name
  library_path   = "${path.module}/lib"

  custom_landing_zones = {
    "${var.root_id}-Hub" = {
      display_name               = "${upper(var.root_id)} Hub"
      parent_management_group_id = "${var.root_id}-landing-zones"
      subscription_ids           = ["d00942f6-41ca-4ea1-8ef4-aa271ffaa70f"]
      archetype_config = {
        archetype_id   = "customer_online"
        parameters     = {
          Deny-Resource-Locations = {
            listOfAllowedLocations = ["eastus","eastus2"]
          }
          Deny-RSG-Locations = {
            listOfAllowedLocations = ["eastus",]
          }
          Deny-Subnet-Without-Nsg = {
            effect = "Audit"
          }
        }
        access_control = {}
      }
    }
    "${var.root_id}-Spokes" = {
      display_name               = "${upper(var.root_id)} Spokes"
      parent_management_group_id = "${var.root_id}-landing-zones"
      subscription_ids           = []
      archetype_config = {
        archetype_id   = "customer_online"
        parameters     = {}
        access_control = {}
      }
    }
  }
  
  # En/disable creation of the core management group hierarchy
  # and additional custom_landing_zones
  deploy_core_landing_zones = true
  # custom_landing_zones      = local.custom_landing_zones
  
  # Configuration settings for identity resources is
  # bundled with core as no resources are actually created
  # for the identity subscription
  deploy_identity_resources    = true
/*  
  configure_identity_resources = {
    settings = {
      identity = {
        config = {
          # Disable this policy as can conflict with Terraform
          enable_deny_subnet_without_nsg = false
        }
      }
    }
  }
*/
  # subscription_id_identity     = var.subscription_id_identity
  
  # The following inputs ensure that managed parameters are
  # configured correctly for policies relating to connectivity
  # resources created by the connectivity module instance and
  # to map the subscription to the correct management group,
  # but no resources are created by this module instance
  deploy_connectivity_resources    = false
  # configure_connectivity_resources = data.terraform_remote_state.connectivity.outputs.configuration
  # subscription_id_connectivity     = data.terraform_remote_state.connectivity.outputs.subscription_id
  
  # The following inputs ensure that managed parameters are
  # configured correctly for policies relating to management
  # resources created by the management module instance and
  # to map the subscription to the correct management group,
  # but no resources are created by this module instance
  deploy_management_resources    = false
  #configure_management_resources = data.terraform_remote_state.management.outputs.configuration
  #subscription_id_management     = data.terraform_remote_state.management.outputs.subscription_id

}

variable "resource_group_name" {
  type    = list(string)
  default = ["rg-test-1", "rg-test-2"]
}

resource "azurerm_resource_group" "test" {
  count    = length(var.resource_group_name)
  name     = element(concat(var.resource_group_name, [""]), count.index)
  location = "eastus"
}

module "service-principal" {
  source  = "kumarvna/service-principal/azuread"
  version = "2.3.0"

  service_principal_name     = "jw-simple-001.jwalters20220923aoutlook.onmicrosoft.com"
  password_rotation_in_years = 1

  # Adding roles and scope to service principal
  assignments = [
    {
      scope                = "/subscriptions/d00942f6-41ca-4ea1-8ef4-aa271ffaa70f"
      role_definition_name = "Contributor"
    },
  ]
}
