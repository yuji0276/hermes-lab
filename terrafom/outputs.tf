output "server_id" {
  description = "作成されたサーバの ID。"
  value       = sakura_server.main.id
}

output "ip_address" {
  description = "共有セグメントで割り当てられたグローバル IP アドレス。"
  value       = sakura_server.main.ip_address
}

output "ssh_command" {
  description = "サーバへ接続するためのコマンド。"
  value       = "ssh ubuntu@${sakura_server.main.ip_address}"
}
