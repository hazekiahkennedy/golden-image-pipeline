terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}

data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-golden-images-${var.yourname}"
  location = var.location
  tags     = var.tags
}

# Azure Compute Gallery
resource "azurerm_shared_image_gallery" "main" {
  name                = "gal_golden_images_${var.yourname}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  description         = "Golden VM images — CIS hardened, built by Packer"
  tags                = var.tags
}

# Image Definition
resource "azurerm_shared_image" "rhel9_cis" {
  name                = "rhel-9-cis"
  gallery_name        = azurerm_shared_image_gallery.main.name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  hyper_v_generation  = "V2"

  identifier {
    publisher = "CloudTechExec"
    offer     = "RHEL"
    sku       = "9-CIS-Hardened"
  }

  tags = var.tags
}

# AAD Application for Packer service principal
resource "azuread_application" "packer" {
  display_name = "sp-packer-golden-images-${var.yourname}"
  owners       = [data.azuread_client_config.current.object_id]
}

# Service Principal
# FIX: azuread v2+ uses client_id, not application_id
resource "azuread_service_principal" "packer" {
  client_id                    = azuread_application.packer.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

# Service Principal Password
# FIX: azuread v2+ uses service_principal_id referencing object_id
resource "azuread_service_principal_password" "packer" {
  service_principal_id = azuread_service_principal.packer.object_id

  rotate_when_changed = {
    rotation_id = "v1"
  }
}

# Role Assignment — Contributor on resource group
resource "azurerm_role_assignment" "packer_contributor" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.packer.object_id
}
