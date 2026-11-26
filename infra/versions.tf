terraform {
  required_version = ">= 1.5"

  required_providers {
    huaweicloud = {
      source  = "huaweicloud/huaweicloud"
      version = "~> 1.94"
    }
  }
}

provider "huaweicloud" {
  region = var.region
}
