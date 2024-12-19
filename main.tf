variable "resource_group_name" { 
  type = string 
  description = "The name of the application and resource group" 
} 

variable "appname" { 
  type = string 
  description = "The name of the application and resource group"  
} 



variable "admin_username" {
  type        = string
  description = "The admin username for the Linux profile"
  default     = "azuser"
}

variable "location" { 
  type = string   
  description = "The Azure location to deploy resources" 
} 

variable "servicebus_namespace_name" { 
  description = "The name of the Service Bus namespace." 
  type = string 
}

variable "key_vault_name" { 
  description = "The name of the Azure Key Vault." 
  type = string 
}


variable "node_vm_size" { 
  type = string 
  default = "Standard_B2s" 
  description = "The size of the VM for the nodes" 
} 

variable "node_count" { 
  type = number 
  default = 2 
  description = "The number of nodes in the default node pool" 
}


terraform { 
  required_providers { 
    azurerm = { 
      source = "hashicorp/azurerm" 
      version = "~> 3.0" 
    } 
  } 
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "acr" { 
  name = var.appname
  resource_group_name = azurerm_resource_group.rg.name 
  location = azurerm_resource_group.rg.location 
  sku = "Basic" 
  admin_enabled = true 
}

resource "azurerm_servicebus_namespace" "sb" { 
  name = var.servicebus_namespace_name 
  resource_group_name = azurerm_resource_group.rg.name 
  location = azurerm_resource_group.rg.location 
  sku = "Standard"     
}

resource "azurerm_key_vault" "kv" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get",
      "List",
      "Create",
      "Update",
      "Delete",      
      "Recover",
      "Backup",
      "Restore",
      "Import"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Backup",
      "Restore",
      "Recover",
      "Purge"
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Delete",
      "Create",
      "Import",
      "Update",
      "ManageContacts",
      "GetIssuers",
      "ListIssuers",
      "SetIssuers",
      "DeleteIssuers",
      "ManageIssuers"
    ]
  }
}

data "azurerm_client_config" "current" {}


resource "tls_private_key" "example" { 
  algorithm = "RSA" 
  rsa_bits = 4096 
} 

resource "local_file" "ssh_key" { 
  content = tls_private_key.example.private_key_pem 
  filename = "${path.module}/id_rsa" 
}



resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.appname
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = var.appname

  default_node_pool {
    name       = "agentpool"
    node_count = var.node_count
    vm_size    = var.node_vm_size
  }

  identity {
    type = "SystemAssigned"
  }    

  azure_policy_enabled = true
  oidc_issuer_enabled = true
  workload_identity_enabled = true

  linux_profile { 
    admin_username = var.admin_username 
    ssh_key { 
      key_data = tls_private_key.example.public_key_openssh 
    } 
  }

  depends_on = [ 
    azurerm_container_registry.acr   
  ]
}

resource "azurerm_role_assignment" "acr_pull" { 
  scope = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull" 
  principal_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id 

  depends_on = [ 
    azurerm_container_registry.acr  
  ]   
}

