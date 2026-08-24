resource "sakura_vswitch" "private" {
  name        = "pri-sw"
  description = "プライベートセグメント用L2スイッチ"
}

resource "sakura_internet" "pub" {
  name = "pubswi+router"

  netmask     = 28
  band_width  = 100
  enable_ipv6 = false

  description = "パブリック用ルーター＋スイッチ"
}
