variable "sakura_access_token" {
  description = "さくらのクラウド API アクセストークン。環境変数 SAKURA_ACCESS_TOKEN でも供給可。"
  type        = string
  default     = null
  sensitive   = true
}
variable "agent_number" {
  description = "エージェントの個数"
  default     = 3
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

variable "server_name_agent" {
  description = "サーバ名。ディスク・SSH鍵・パケットフィルタ名の接頭辞にも使う。"
  type        = string
  default     = "agent"
}

variable "server_name_control" {
  description = "サーバ名。ディスク・SSH鍵・パケットフィルタ名の接頭辞にも使う。"
  type        = string
  default     = "ansible"
}


variable "core" {
  description = "仮想コア数。"
  type        = number
  default     = 2
}

variable "memory" {
  description = "メモリサイズ（GB）。"
  type        = number
  default     = 4
}

variable "disk_size_agent" {
  description = "エージェント用VMディスクサイズ"
  type        = number
  default     = 40
}
variable "disk_size_log" {
  description = "ログ収集用VMディスクサイズ（GB）。"
  type        = number
  default     = 100
}
variable "disk_size_monitor" {
  description = "監視用VMディスクサイズ"
  type        = number
  default     = 40
}
variable "disk_size_proxy" {
  description = "proxy用VMディスクサイズ"
  type        = number
  default     = 40

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
