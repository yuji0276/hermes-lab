#さくらのパケットフィルターは受信のみのフィルタリングを行う
resource "sakura_packet_filter" "global_in" {
  name        = "global_in_filter"
  description = "グローバルからのフィルター"
}

resource "sakura_packet_filter_rules" "global_in_rules" {
  packet_filter_id = sakura_packet_filter.global_in.id

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

resource "sakura_packet_filter" "agent_log_private_in" {
  name        = "private_in_filter"
  description = "agent,logの受信用フィルター"
}

resource "sakura_packet_filter_rules" "agent_log_private_in" {
  packet_filter_id = sakura_packet_filter.agent_log_private_in.id

  expression = [
    {
      protocol    = "icmp"
      allow       = true
      description = "ping"
    },
    //controlからのssh(Ansible)を許可
    {
      protocol         = "tcp"
      source_network   = cidrhost(local.private_cidr, local.fixed_servers["control"].private_host)
      destination_port = "22"
      allow            = true
      description      = "BootStrap"
    },
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
resource "sakura_packet_filter" "infra_private_in" {
  name        = "private_in_filter"
  description = "control,monitorのフィルター"
}
resource "sakura_packet_filter_rules" "infra_private_in" {
  packet_filter_id = sakura_packet_filter.infra_private_in.id

  expression = [
    {
      protocol    = "icmp"
      allow       = true
      description = "ping"
    },
    //controlからのssh(Ansible)を許可
    {
      protocol         = "tcp"
      source_network   = cidrhost(local.private_cidr, local.fixed_servers["control"].private_host)
      destination_port = "22"
      allow            = true
      description      = "BootStrap"
    },
    {
      protocol         = "tcp"
      source_network   = "192.168.100.0/24"
      destination_port = "22"
      allow            = false
      description      = "ssh"
    },
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
resource "sakura_packet_filter" "proxy_private_in" {
  name        = "private_in_filter"
  description = "proxyのプライベートフィルター"
}
resource "sakura_packet_filter_rules" "proxy_private_in" {
  packet_filter_id = sakura_packet_filter.proxy_private_in.id

  expression = [
    {
      protocol    = "icmp"
      allow       = true
      description = "ping"
    },
    //Bootstrapを許可
    {
      protocol         = "tcp"
      source_network   = cidrhost(local.private_cidr, local.fixed_servers["control"].private_host)
      destination_port = "22"
      allow            = true
      description      = "BootStrap"
    },
    {
      protocol         = "tcp"
      source_network   = "192.168.100.0/24"
      destination_port = "22"
      allow            = false
      description      = "ssh"
    },
    //ephemeral許可
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
    //agentからの接続を許可。squidは3128を受け取る
    {
      protocol         = "tcp"
      source_network   = "192.168.100.0/24"
      destination_port = "3128"
      allow            = true
      description      = "squid"
    },
    {
      protocol    = "ip"
      allow       = false
      description = "deny all"
    },
  ]
}
