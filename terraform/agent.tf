resource "sakura_disk" "agent" {
  count             = var.agent_number
  name              = "agent-disk-${count.index + 1}"
  source_archive_id = data.sakura_archive.ubuntu.id
  size              = var.disk_size_agent
}

resource "sakura_server" "agent" {
  count       = var.agent_number
  name        = "agent-${count.index + 1}"
  disks       = [sakura_disk.agent[count.index].id]
  core        = var.core
  memory      = var.memory
  description = "for agent"
  tags        = ["agent"]

  network_interface = [{
    upstream         = sakura_vswitch.private.id
    packet_filter_id = sakura_packet_filter.private_in.id
  }]

  disk_edit_parameter = {
    hostname        = var.server_name_agent
    ssh_key_ids     = [sakura_ssh_key.main.id]
    netmask         = var.netmask
    ip_address      = "192.168.100.${count.index + 11}"
    disable_pw_auth = true
  }
}
