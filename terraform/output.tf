output "global_ips" {
  value = {
    for k, s in local.servers : k => sakura_internet.pub.ip_addresses[s.global_index]
    if s.global_index != null
  }
}

output "private_ips" {
  value = {
    for k, s in local.servers : k => cidrhost(local.private_cidr, s.private_host)
  }
}
