resource "sakura_packet_filter" "global_in" {
  name        = "global_in_filter"
  description = "インターネットからの受信用フィルター"
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

resource "sakura_packet_filter" "private_in" {
  name        = "private_in_filter"
  description = "controler,monitor,proxyからの受信フィルター"
}

resource "sakura_packet_filter_rules" "private_in_rules" {
  packet_filter_id = sakura_packet_filter.private_in.id

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
