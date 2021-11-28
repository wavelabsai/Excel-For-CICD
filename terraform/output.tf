output "ip" {
  value = "public_ip = ${local.public_ip} and private_ip = ${local.agw_ips}"
}
