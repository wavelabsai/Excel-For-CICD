resource "openstack_networking_floatingip_v2" "myip" {
  pool = "${var.public_network_name}"
}

resource "openstack_networking_port_v2" "ports" {
  count          = 2
  name           = "${format("port-%02d", count.index + 1)}"
  network_id     = "${var.private_network_id}"
  admin_state_up = "true"
  port_security_enabled = "false"
}

data "template_file" "user_data" {
  template = file("${path.module}/templates/user_data.yaml")
}

resource "openstack_compute_instance_v2" "agw_deployment" {
  name            = "${var.prefix}-agw"
  image_id        = "${var.image_id}"
  flavor_id       = "${var.flavor_id}"
  key_pair        = openstack_compute_keypair_v2.demo_keypair.name
  user_data       = data.template_file.user_data.rendered

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
      "sudo apt-get upgrade -y",
      "echo '127.0.0.1 localhost ${var.prefix}-agw' | sudo tee /etc/hosts"
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
  public_ip = "${openstack_networking_floatingip_v2.myip.address}"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              
}

resource "local_file" "ansible_hosts_cfg" {
  content = templatefile("${path.module}/templates/hosts.tpl",
    {
      agw0_ip = openstack_networking_port_v2.ports.*.all_fixed_ips[0],
      agw1_ip = openstack_networking_port_v2.ports.*.all_fixed_ips[1]
    }
  )
  filename = "../ansible/agw_ansible_hosts"
}
