# 公開鍵を登録し、ディスク修正時にサーバへ流し込む
resource "sakura_ssh_key" "main" {
  name       = "${var.server_name_control}-key"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}
