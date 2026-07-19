terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    ncloud = {
      source  = "NaverCloudPlatform/ncloud"
      version = "4.0.5"
    }
  }
}

provider "ncloud" {
  region      = var.region
  site        = "public"
  support_vpc = true
}
