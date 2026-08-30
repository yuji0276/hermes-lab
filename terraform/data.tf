data "sakura_archive" "ubuntu" {
  name = "Ubuntu Server 24.04.2 LTS 64bit (cloudimg)"
  zone = var.zone
}
data "sakura_zone" "current" {}
