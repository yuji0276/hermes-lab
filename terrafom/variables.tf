variable "sakura_access_token" {
  description = "さくらのクラウド API アクセストークン。環境変数 SAKURA_ACCESS_TOKEN でも供給可。"
  type        = string
  default     = null
  sensitive   = true
}

variable "sakura_access_token_secret" {
  description = "さくらのクラウド API アクセストークンシークレット。環境変数 SAKURA_ACCESS_TOKEN_SECRET でも供給可。"
  type        = string
  default     = null
  sensitive   = true
}

variable "zone" {
  description = "リソースを作成するゾーン。tk1a / tk1b / is1a / is1b / is1c から選択。"
  type        = string
  default     = "is1c"
}

variable "server_name" {
  description = "サーバ名。ディスク・SSH鍵・パケットフィルタ名の接頭辞にも使う。"
  type        = string
  default     = "vm01"
}

variable "core" {
  description = "仮想コア数。"
  type        = number
  default     = 4
}

variable "memory" {
  description = "メモリサイズ（GB）。"
  type        = number
  default     = 12
}

variable "disk_size" {
  description = "ディスクサイズ（GB）。"
  type        = number
  default     = 500
}

variable "os_type" {
  description = "元にするパブリックアーカイブの種別。ubuntu2404 / ubuntu2204 / debian12 / rockylinux9 など。"
  type        = string
  default     = "ubuntu2404"
}

variable "ssh_public_key_path" {
  description = "サーバに登録する SSH 公開鍵のパス。"
  type        = string
  default     = "~/.ssh/helmes.pub"
}

variable "allowed_ssh_cidr" {
  description = "SSH(22/tcp) を許可する送信元 CIDR。0.0.0.0/0 は全世界に開放されるので、可能なら自宅・オフィスの IP に絞る。"
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "リソースに付与するタグ。"
  type        = set(string)
  default     = ["terraform"]
}
