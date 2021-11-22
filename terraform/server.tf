resource "openstack_networking_floatingip_v2" "myip" {
  pool = "public"

}

resource "openstack_networking_port_v2" "ports" {
  count          = 2
  name           = "${format("port-%02d", count.index + 1)}"
  network_id     = "edb1363e-25d3-46f7-bcab-effec6fd7e49"
  admin_state_up = "true"
  port_security_enabled = "false"
}

resource "openstack_compute_instance_v2" "agw_deployment" {
  name            = "${var.prefix}-agw"
  image_id        = "18b0a432-b94a-414c-83f0-b22d9134f3ec"
  flavor_id       = "3"
  key_pair        = openstack_compute_keypair_v2.demo_keypair.name

  // security_groups = ["default"]

  metadata = {
    type  = "terraform_test"
  }

  network {
    port = "${openstack_networking_port_v2.ports.*.id[0]}"
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update", 
      "sudo apt-get upgrade -y"
      ]

    connection {
      host        = self.access_ip_v4
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.pvt_key)
    }
  }
  
  depends_on = [openstack_compute_keypair_v2.demo_keypair, openstack_networking_port_v2.ports]
}

resource "openstack_compute_interface_attach_v2" "attachments" {
  instance_id = "${openstack_compute_instance_v2.agw_deployment.id}"
  port_id     = "${openstack_networking_port_v2.ports.*.id[1]}"
}

resource "openstack_networking_floatingip_associate_v2" "myip" {
  floating_ip = "${openstack_networking_floatingip_v2.myip.address}"
  port_id = "${openstack_networking_port_v2.ports.*.id[1]}"
}

locals {
  agw_ips = [ for ip in openstack_networking_port_v2.ports: ip.all_fixed_ips[0]]                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
}

resource "local_file" "ansible_hosts_cfg" {
  content = templatefile("${path.module}/templates/hosts.tpl",
    {
      agw0_ip = openstack_networking_port_v2.ports.*.all_fixed_ips[0],
      agw1_ip = openstack_networking_port_v2.ports.*.all_fixed_ips[1]
    }
  )
  filename = "../ansible/orc8r_ansible_hosts"
}
