resource "sakura_disk" "this" {
  for_each          = local.servers
  name              = "${each.key}-disk"
  source_archive_id = data.sakura_archive.ubuntu.id
  size              = each.value.disk_size
}

resource "sakura_server" "this" {
  for_each = local.servers
  name     = each.key
  disks    = [sakura_disk.this[each.key].id]
  core     = var.core
  memory   = var.memory

  description = each.value.description
  tags        = [each.value.role]

  network_interface = concat(
    each.value.global_index == null ? [] : [{
      upstream = sakura_internet.pub.vswitch_id

      packet_filter_id = sakura_packet_filter.global_in.id
    }],
    [{
      upstream         = sakura_vswitch.private.id
      packet_filter_id = sakura_packet_filter.private_in.id
    }]
  )
  user_data = templatefile(
    "${path.module}/cloudinit/${each.value.global_index == null ? "single_nic" :
    "dual_nic"}.yaml",
    {
      hostname        = each.key
      ssh_public_key  = trimspace(file(pathexpand(var.ssh_public_key_path)))
      private_ip      = cidrhost(local.private_cidr, each.value.private_host)
      private_prefix  = local.private_prefix
      private_gateway = local.private_gateway
      global_ip       = each.value.global_index == null ? "" : sakura_internet.pub.ip_addresses[each.value.global_index]
      global_prefix   = var.global_netmask
      global_gateway  = sakura_internet.pub.gateway
      dns_servers     = join(", ", data.sakura_zone.current.dns_servers)
    }
  )
}
