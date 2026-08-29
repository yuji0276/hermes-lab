output "control_global_ip" { value = sakura_server.control.ip_address }
output "monitor_global_ip" { value = sakura_server.monitor.ip_address }
output "gateway" { value = sakura_internet.pub.gateway }
output "agent1_ip" { value = sakura_server.agent[0].ip_address }
