variable "existing_acr_name" { 
  type = string
  default = "v2train" 
  description = "The name of the existing Azure Container Registry" 
} 

variable "existing_acr_rg" { 
  type = string
  default = "v2train" 
  description = "The resource group of the existing Azure Container Registry" 
}

variable "appname" { 
  type = string 
  description = "The name of the application and resource group" 
  default = "v2train"
} 

variable "location" { 
  type = string 
  default = "eastus" 
  description = "The Azure location to deploy resources" 
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


provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = var.appname
  location = var.location
}

data "azurerm_container_registry" "existing_acr" { 
    name = var.existing_acr_name 
    resource_group_name = var.existing_acr_rg 
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

  
  addon_profile { 
    kube_dashboard { 
        enabled = true 
        } 
    } 

   linux_profile { 
    admin_username = "azureuser" 
    ssh_key { 
      key_data = file("~/.ssh/id_rsa.pub")
    } 
   }
  
   network_profile { 
     network_plugin = "azure" 
     load_balancer_sku = "standard" 
     outbound_type = "loadBalancer" 
   } 


  azure_policy_enabled = true
  enable_oidc_issuer = true
  enable_workload_identity = true
}

resource "azurerm_role_assignment" "acr_pull" { 
  scope = azurerm_container_registry.existing_acr.id 
  role_definition_name = "AcrPull" 
  principal_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id 
}

