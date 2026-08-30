output "global_ips" {
  value = {
    for k, s in local.servers : k => sakura_server.this[k].ip_address
    if s.global_index != null
  }
}

output "private_ips" {
  value = {
    for k, s in local.servers : k => cidrhost(local.private_cidr, s.private_host)
  }
}
