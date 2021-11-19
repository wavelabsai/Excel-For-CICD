output "ip" {
  // value = "${openstack_compute_instance_v2.agw_deployment.*.access_ip_v4}"
  value = "${local.agw_ips}"
}
//${join(",", module.xtradb_servers.network_interface_private_ip)}
