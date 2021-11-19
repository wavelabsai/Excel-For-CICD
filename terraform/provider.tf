terraform {
    required_version = ">= 0.14.0"
    required_providers {
        openstack = {
            source  = "terraform-provider-openstack/openstack"
            version = "~> 1.35.0"
        }
        rancher2 = {
            source = "rancher/rancher2"
            version = "1.13.0"
        }
    }
}

# Openstack provider to communicate with openstack apis
provider "openstack" {
  user_name   = var.openstack_username
  tenant_name = var.openstack_project
  password    = var.openstack_password
  auth_url    = var.openstack_auth_url
  domain_name = var.openstack_domain
}