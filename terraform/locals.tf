locals {
  private_cidr    = "192.168.100.0/24"
  private_prefix  = tonumber(split("/", local.private_cidr)[1])
  private_gateway = cidrhost(local.private_cidr, 1)

  fixed_servers = {
    proxy = {
      role              = "proxy",
      disk_size         = var.disk_size_proxy,
      global_index      = 2,
      private_host      = 1,
      description       = "外向き通信用proxyVM",
      private_filter_id = "proxy_private_in",
    }
    control = {
      role              = "control",
      disk_size         = var.disk_size_proxy,
      global_index      = 0,
      private_host      = 2,
      description       = "Ansible用BootstrapVM",
      private_filter_id = "infra_private_in"
    }
    monitor = {
      role              = "monitor",
      disk_size         = var.disk_size_monitor,
      global_index      = 1,
      private_host      = 3,
      description       = "agent監視VM",
      private_filter_id = "infra_private_in"
    }
    log = {
      role              = "log",
      disk_size         = var.disk_size_log,
      global_index      = null,
      private_host      = 4,
      description       = "ログ回収VM",
      private_filter_id = "agent_log_private_in",
    }
  }
  agent_servers = {
    for i in range(var.agent_number) : "${var.server_name_agent}-${i + 1}" => {
      role = "agent", disk_size = var.disk_size_agent, global_index = null, private_host = 11 + i, description = "エージェント用VM", private_filter = "agent_log_private_in"
    }
  }

  servers = merge(local.fixed_servers, local.agent_servers)
}
