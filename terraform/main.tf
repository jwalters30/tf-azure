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
        archetype_id = "customer_online"
        parameters = {
          Deny-Resource-Locations = {
            listOfAllowedLocations = ["eastus", "eastus2"]
          }
          Deny-RSG-Locations = {
            listOfAllowedLocations = ["eastus", "eastus2"]
          }
          Deny-Subnet-Without-Nsg-garbage = {
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
  deploy_identity_resources = true
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
  deploy_connectivity_resources = false
  # configure_connectivity_resources = data.terraform_remote_state.connectivity.outputs.configuration
  # subscription_id_connectivity     = data.terraform_remote_state.connectivity.outputs.subscription_id

  # The following inputs ensure that managed parameters are
  # configured correctly for policies relating to management
  # resources created by the management module instance and
  # to map the subscription to the correct management group,
  # but no resources are created by this module instance
  deploy_management_resources = false
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

resource "azurerm_virtual_network" "test" {
  name                = "JimVnet"
  resource_group_name = "rg-test-1"
  location            = "eastus"
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "snet" {
  name                 = "subnet1"
  resource_group_name  = "rg-test-1"
  virtual_network_name = azurerm_virtual_network.test.name
  address_prefixes     = ["10.0.0.0/24"]
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

/*
resource "azurerm_public_ip" "public_ip" {
  name                = "vm_public_ip"
  resource_group_name = azurerm_resource_group.test[0].name
  location            = azurerm_resource_group.test[0].location
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "example" {
  name                = "example-nic"
  location            = azurerm_resource_group.test[0].location
  resource_group_name = azurerm_resource_group.test[0].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "rdp_nsg"
  location            = azurerm_resource_group.test[0].location
  resource_group_name = azurerm_resource_group.test[0].name

  security_rule {
    name                       = "allow_rdp_russ"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "98.97.6.187/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = azurerm_network_interface.example.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "example" {
  name                = "example-machine"
  resource_group_name = azurerm_resource_group.test[0].name
  location            = azurerm_resource_group.test[0].location
  size                = "Standard_D2as_v5"
  admin_username      = "foolishuser"
  admin_password      = "P@$$w0rdAwful2023!"
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]
  identity {
    type = "SystemAssigned"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }
}
*/
