packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2.0"
    }
  }
}

variable "subscription_id" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "gallery_name" {
  type    = string
  default = "gal_golden_images_hazekiah"
}

variable "image_definition" {
  type    = string
  default = "rhel-9-cis"
}

variable "location" {
  type    = string
  default = "West US 2"
}

variable "build_vm_size" {
  description = "Size of the temporary VM Packer uses during the build. Deleted after image capture."
  type        = string
  default     = "Standard_D2s_v3"
}

source "azure-arm" "rhel9_cis" {
  use_azure_cli_auth = true

  subscription_id = var.subscription_id
  vm_size         = var.build_vm_size
  build_resource_group_name = var.resource_group
  image_publisher = "RedHat"
  image_offer     = "RHEL"
  image_sku       = "9-lvm-gen2"
  image_version   = "latest"

  os_type         = "Linux"
  os_disk_size_gb = 30

  managed_image_name                = "rhel-9-cis-{{timestamp}}"
  managed_image_resource_group_name = var.resource_group

  shared_image_gallery_destination {
    resource_group      = var.resource_group
    gallery_name        = var.gallery_name
    image_name          = var.image_definition
    image_version       = "1.0.{{timestamp}}"
    replication_regions = ["West US 2", "East US"]
  }

  azure_tags = {
    project    = "golden-images"
    hardening  = "cis-level1"
    managed_by = "packer"
  }
}

build {
  sources = ["source.azure-arm.rhel9_cis"]

  provisioner "shell" {
    inline = [
      "echo 'Updating package index...'",
      "sudo dnf update -y",
      "sudo dnf install -y audit audispd-plugins aide"
    ]
  }

  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/hardening.sh",
      "${path.root}/scripts/cleanup.sh"
    ]
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
  }

  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
