resource "sakura_disk" "log" {
  name              = "log-disk"
  source_archive_id = data.sakura_archive.ubuntu.id
  size              = var.disk_size_log
}
resource "sakura_disk" "monitor" {
  name              = "monitor-disk"
  source_archive_id = data.sakura_archive.ubuntu.id
  size              = var.disk_size_monitor
}

resource "sakura_server" "log" {
  name        = "log"
  disks       = [sakura_disk.log.id]
  description = "エージェントのログ回収用VM"
  tags        = ["monitor"]

  network_interface = [{
    upstream         = sakura_vswitch.private.id
    packet_filter_id = sakura_packet_filter.global_in.id
  }]

  disk_edit_parameter = {
    hostname        = "log"
    ssh_key_ids     = [sakura_ssh_key.main.id]
    disable_pw_auth = true
  }
}

resource "sakura_server" "monitor" {
  name        = "monitor"
  disks       = [sakura_disk.monitor.id]
  description = "エージェントのログ回収用VM"
  tags        = ["monitor"]

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
    hostname        = "log"
    ssh_key_ids     = [sakura_ssh_key.main.id]
    disable_pw_auth = true
  }
}
