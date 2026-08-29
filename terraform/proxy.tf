resource "sakura_disk" "proxy" {
  name              = "proxy_disk"
  source_archive_id = data.sakura_archive.ubuntu.id
  size              = var.disk_size_proxy
}

resource "sakura_server" "proxy" {
  name        = "proxy"
  disks       = [sakura_disk.proxy.id]
  memory      = var.memory
  core        = var.core
  description = "エージェントの外向き通信用proxyVM"
  tags        = ["proxy"]

  network_interface = [
    {
      upstream         = sakura_internet.pub.vswitch_id
      packet_filter_id = sakura_packet_filter.global_in.id
    },
    {
      upstream         = sakura_vswitch.private.id
      packet_filter_id = sakura_packet_filter.private_in.id
    }
  ]

  disk_edit_parameter = {
    netmask         = var.netmask
    ip_address      = sakura_internet.pub.ip_addresses[local.global_ip_index.proxy]
    hostname        = "proxy"
    ssh_key_ids     = [sakura_ssh_key.main.id]
    disable_pw_auth = true
  }
}
