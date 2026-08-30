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
  disk_edit_parameter = {
    hostname        = each.key
    ssh_key_ids     = [sakura_ssh_key.main.id]
    disable_pw_auth = true

    ip_address = each.value.global_index == null ? cidrhost(local.private_cidr, each.value.private_host) : sakura_internet.pub.ip_addresses[each.value.global_index]
    netmask    = each.value.global_index == null ? local.private_prefix : var.global_netmask
    gateway    = each.value.global_index == null ? null : sakura_internet.pub.gateway
  }
}
