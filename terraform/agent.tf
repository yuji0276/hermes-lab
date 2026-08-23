
data "sakura_archive" "ubuntu" {
  os_type = var.os_type
}

# 公開鍵を登録し、ディスク修正時にサーバへ流し込む
resource "sakura_ssh_key" "main" {
  name       = "${var.server_name_control}-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}


resource "sakura_disk" "agent" {
  count             = 3
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
    disable_pw_auth = true
  }
}
