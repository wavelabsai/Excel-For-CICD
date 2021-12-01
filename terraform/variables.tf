variable "prefix" {
  type = string
  description = "A prefix for created resources to avoid clashing names"
}

variable "public_key" {
  type = string
  description = "SSH Public key content to be imported and used into created instances"
}

variable "pvt_key" {
  type = string
  description = "SSH private key"
}

variable "openstack_project" {
  type = string
  description = "Openstack project/tenant name"
}
variable "openstack_username" {
  type = string
  description = "Openstack username which resources will be created by"
}
variable "openstack_password" {
  type = string
  description = "Openstack password"
  sensitive = true
}
variable "openstack_auth_url" {
  type = string
  description = "Authentication url for openstack cli"
}
variable "openstack_domain" {
  type = string
  description = "Openstack domain name which tenant exists on"
}

variable "flavor_id" {
  type = string
  description = "Openstack Flavor ID"
}