resource "sakura_disk" "control" {
  name              = "control_disk"
  source_archive_id = data.sakura_archive.ubuntu.id
  size              = var.disk_size_control
}

resource "sakura_server" "control" {
  name        = "control"
  disks       = [sakura_disk.control.id]
  memory      = var.memory
  core        = var.core
  description = "Ansible用BootstrapVM"
  tags        = ["control"]

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
    gateway         = sakura_internet.pub.gateway
    netmask         = var.netmask
    ip_address      = sakura_internet.pub.ip_addresses[local.global_ip_index.control]
    hostname        = "control"
    ssh_key_ids     = [sakura_ssh_key.main.id]
    disable_pw_auth = true
  }
}
