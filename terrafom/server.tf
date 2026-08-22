# ------------------------------------------------------------------
# VM 1台構成: SSH 公開鍵 + パケットフィルタ + Ubuntu ディスク + サーバ
# ------------------------------------------------------------------

data "sakura_archive" "ubuntu" {
  os_type = var.os_type
}

# 公開鍵を登録し、ディスク修正時にサーバへ流し込む
resource "sakura_ssh_key" "main" {
  name       = "${var.server_name}-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

# パケットフィルタ本体（ルールは別リソースで管理する）
resource "sakura_packet_filter" "main" {
  name        = "${var.server_name}-filter"
  description = "Managed by Terraform"
}

resource "sakura_packet_filter_rules" "main" {
  packet_filter_id = sakura_packet_filter.main.id

  # 上から順に評価され、最初にマッチしたルールが適用される
  expression = [
    {
      protocol    = "icmp"
      allow       = true
      description = "ping"
    },
    {
      protocol         = "tcp"
      source_network   = var.allowed_ssh_cidr
      destination_port = "22"
      allow            = true
      description      = "ssh"
    },
    # さくらのパケットフィルタは受信方向のみを見るため、
    # 自分から出した通信の戻りパケットを明示的に通す必要がある
    {
      protocol         = "tcp"
      destination_port = "32768-61000"
      allow            = true
      description      = "tcp response"
    },
    {
      protocol         = "udp"
      destination_port = "32768-61000"
      allow            = true
      description      = "udp response"
    },
    {
      protocol    = "ip"
      allow       = false
      description = "deny all"
    },
  ]
}

resource "sakura_disk" "main" {
  name              = "${var.server_name}-disk"
  source_archive_id = data.sakura_archive.ubuntu.id
  size              = var.disk_size
}

resource "sakura_server" "main" {
  name        = var.server_name
  disks       = [sakura_disk.main.id]
  core        = var.core
  memory      = var.memory
  description = "Managed by Terraform"
  tags        = var.tags

  network_interface = [{
    upstream         = "shared"
    packet_filter_id = sakura_packet_filter.main.id
  }]

  # 公開鍵のみでログインする（パスワード認証は無効）
  disk_edit_parameter = {
    hostname        = var.server_name
    ssh_key_ids     = [sakura_ssh_key.main.id]
    disable_pw_auth = true
  }
}
