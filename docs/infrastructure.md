# hermes インフラ設計

さくらのクラウド is1c 上に、LLM エージェント実行環境を 7 VM で構成する。
プロビジョニングは Terraform + cloud-init、その先の構成管理は Ansible が担当する。

- 対象: `terraform/` 配下
- provider: `sacloud/sakura` v3
- OS: Ubuntu Server 24.04.2 LTS 64bit **(cloudimg)**

---

## 1. 構成

```
GLOBAL /28  ── router+switch ── gw = sakura_internet.pub.gateway
  │           │           │
control     monitor      proxy          ← 2枚NIC (ens3=global / ens4=private)
  │           │           │
──┴───────────┴───────────┴────────────────────────────  PRIVATE 192.168.100.0/24
                          │                              (vswitch = 純粋なL2、ルータもDHCPも無い)
            ┌─────────┬───┴─────┬─────────┐
           log      agent-1   agent-2   agent-3          ← 1枚NIC (ens3=private)
```

プライベートセグメントはルータを持たない L2 スイッチである。したがって
**このセグメントで通信するホストは、例外なく自分で IP を持つ必要がある**。
Terraform の `network_interface` が行うのは L2 の結線までで、L3 は cloud-init の責務。

### 役割

| ホスト | 役割 |
|---|---|
| control | Ansible 実行元。踏み台 |
| proxy | agent の外向き通信を仲介。プライベート側のデフォルトゲートウェイ |
| monitor | トークン使用量など agent の監視 |
| log | agent のログ回収 |
| agent-1..3 | LLM エージェント本体 |

---

## 2. アドレス設計

### プライベート 192.168.100.0/24

`locals.private_cidr` を単一の情報源とし、`cidrhost()` で導出する。直書きしない。

| ホスト | IP | デフォルトルート |
|---|---|---|
| proxy | .1 | global gw (ens3) |
| control | .2 | global gw (ens3) |
| monitor | .3 | global gw (ens3) |
| log | .4 | 192.168.100.1 (proxy) |
| agent-1..3 | .11 – .13 | 192.168.100.1 (proxy) |

`.5` – `.10` は将来のインフラ用に空けてある。
`.1` を proxy に充てたのは、プライベート専用ホストのゲートウェイが慣例どおり `.1` に座るようにするため。

### グローバル /28

`sakura_internet.pub` が確保するブロックから採る。**destroy するとブロックが解放され、
次の apply で別のアドレスが割り当たる**ので、IP をどこかに固定で書いてはいけない。

`locals.fixed_servers[].global_index` が `sakura_internet.pub.ip_addresses` の添字を指す。

| ホスト | global_index |
|---|---|
| control | 0 |
| monitor | 1 |
| proxy | 2 |

`global_index = null` のホストはプライベート専用として扱われ、
`servers.tf` の分岐で NIC 構成と netplan の内容が切り替わる。

### DNS

プライベート専用ホストは DHCP が無いためリゾルバを明示する必要がある。
ハードコードせず `data.sakura_zone.current.dns_servers` を使う。

---

## 3. Terraform 構成

```
terraform/
├── terrafomrm.tf     provider / required_version   ※ファイル名は typo。未修正
├── variables.tf
├── locals.tf         アドレス設計とサーバ定義マップ
├── data.tf           アーカイブ / ゾーン
├── network.tf        vswitch / internet
├── packet_filter.tf
├── ssh_key.tf        ※ 現在どこからも参照されていない
├── servers.tf        disk + server（for_each で7台）
├── output.tf
└── cloudinit/
    ├── single_nic.yaml    log, agent-1..3
    └── dual_nic.yaml      control, monitor, proxy
```

### モジュールではなく for_each

7台は構造が同一で、差分はディスクサイズ・NIC構成・IP・タグのみ。
`locals.servers` にその差分だけをデータとして持ち、`sakura_disk` / `sakura_server` を
各1リソースの `for_each` で展開する。

役割ごとに `.tf` を分けていた頃は 165 行だったものが、locals + servers で約 61 行になった。
モジュール化も検討したが、変数を宣言・受け渡し・使用の3回書かせるため、
ルート構成が1つしかない現状では削減効果がほぼ無い（実測 139 行）。
dev/stg/prod のようにルート構成が複数になったら再検討する。

`count` ではなく `for_each` を使うのは、agent を1台減らしたときに添字がずれて
無関係な台まで再作成されるのを避けるため。

---

## 4. cloud-init 設計

### なぜ cloud-init なのか

発端は「control の eth1（プライベート側）に IP が付かない」ことだった。
`disk_edit_parameter` は `ip_address` を1つしか持てず、**eth0 しか設定できない**。

代替手段を検討した結果、cloud-init 以外に選択肢が無かった。

- **スタートアップスクリプト方式**: provider v3 に `sakura_note` リソースが存在しない。
  `disk_edit_parameter.script` は既存ノートの id を要求するため、
  コントロールパネルで手動作成する必要があり IaC が途切れる。
- **Ansible 方式**: Ansible を動かす control 自身のプライベート NIC が設定できない（鶏卵）。

### 責務の移動

`disk_edit_parameter` は全廃した。両者は provider 上も排他である。

| 旧 (`disk_edit_parameter`) | 新 (cloud-config) |
|---|---|
| `hostname` | `hostname:` / `fqdn:` |
| `ssh_key_ids` | `users[].ssh_authorized_keys` |
| `disable_pw_auth` | `ssh_pwauth: false` |
| `ip_address` / `netmask` / `gateway` | `write_files` で netplan を配置 |

### ネットワーク設定の方法

さくらの cloud-init は **network-config を受け付けない**。
`write_files` で `/etc/netplan/60-hermes.yaml` を置き、`runcmd` で `netplan apply` するのが唯一の方法。

- ファイル名の `60-` に意味がある。cloud-init 自身が `50-cloud-init.yaml` を生成するため、
  辞書順で後に来る `60-` が後勝ちで上書きする。`40-` では負ける。
- `permissions: "0600"` はクォート必須。外すと YAML が 8進数ではなく 10進数 600 と解釈する。
- `runcmd` が必要なのは実行順序のため。cloud-init のネットワークステージは
  `write_files` より先に走るので、置いた時点では未反映。2回目以降のブートでは
  netplan が起動時に読むため、この行は初回ブート専用。
- `ens4`（プライベート側）に `routes` は書かない。デフォルトルートが2本になると経路が非決定になる。

### テンプレート変数

`templatefile()` に渡す。名前は任意で、さくら固有の命名規約は無い。
足りないキーはエラー、余分なキーは無視されるため、両テンプレートに同じマップを渡してよい。

`hostname` / `ssh_public_key` / `private_ip` / `private_prefix` / `private_gateway` /
`global_ip` / `global_prefix` / `global_gateway` / `dns_servers`

シェル変数を書く場合は `$${VAR}` とエスケープする（`${VAR}` は Terraform に食われる）。

### cloud-init に置くものの線引き

**ネットワーク・ユーザ・SSH鍵のみ**とし、それ以外は Ansible に寄せる。

理由は2つ。

1. `user_data` の変更はサーバ再作成を誘発する。cloud-config を1文字直すたびに VM が作り直される。
2. agent と log は proxy の NAT が未整備の間、外に出られない。
   `package_update` や `packages:` を書くと初回ブートで到達不能な相手を待ち続け、
   タイムアウトするまでブートが止まる。

---

## 5. さくら固有の制約（実地で確定した事項）

マニュアルに記載が無く、VM の作り直しを繰り返して判明したもの。

### cloudimg アーカイブは「ディスクの修正」に非対応

`disk_edit_parameter` を書いても **API はエラーを返さず黙って無視する**。
`terraform apply` は成功し、`terraform plan` は `No changes` と表示する。
実機だけが IP もホスト名も SSH 鍵も無い状態で起動する。

cloudimg を選ぶなら `user_data` 一本に寄せるしかない。

### NIC 名は `eth0` ではなく `ens3` / `ens4`

さくら独自の非 cloudimg アーカイブは `net.ifnames=0` 相当の設定で `eth0` になるが、
cloudimg は素の Ubuntu なので systemd の predictable interface names が有効。

QEMU のデフォルト PCI 配置ではスロット 0–2 がホストブリッジ等に使われるため、
1本目の NIC が `ens3`、2本目が `ens4` になる。`network_interface` に並べた順と対応する。

**netplan は存在しない NIC 名を指定されてもエラーを出さず、何も設定せずに正常終了する。**

環境によっては `enp0s3` 形式になる可能性もあるため、新しいイメージを使うときは
必ず `ip -br link` で実物を確認すること。

### データソース

`DataSourceNoCloud [seed=/dev/vdb]`。user_data はシードディスクとして VM に接続される。

### アーカイブの指定

`os_type` に cloudimg の選択肢が無いため `data "sakura_archive"` は `name` でピン留めする。

```hcl
name = "Ubuntu Server 24.04.2 LTS 64bit (cloudimg)"
```

非 cloudimg 版の名前が cloudimg 版の先頭一致部分文字列になっているため誤爆を懸念したが、
実際には正しく解決された。ただし名前にパッチバージョンが含まれるため、
さくらが 24.04.3 を公開しても自動追随しない。再現性と引き換えのトレードオフとして受け入れる。

### パケットフィルタ

**受信方向のみ・ステートレス**。だから ephemeral ポート（32768-61000）の許可ルールが要る。
agent が proxy 経由で外に出た戻りパケットは、agent 側の受信で ephemeral にマッチして通る。

---

## 6. 検証手順

`content: |` の中身は外側の YAML から見れば**ただの文字列**である。
中身が壊れていても外側のパースは成功し、`terraform validate` も
`cloud-init schema` も通る。層を分けて検証する必要がある。

### 層1・2・3 — 手元

以下を `cloudinit/check.sh` として置くと使い回せる。
macOS には PyYAML が入っていないため Ruby を使う。

```bash
sed -E 's/\$\{[a-z_]+\}/X/g' "$1" | ruby -ryaml -e '
doc = begin
  YAML.safe_load(STDIN.read)
rescue => e
  abort "[1] 外側 cloud-config: FAIL  #{e.message}"
end
puts "[1] 外側 cloud-config: OK  keys=#{doc.keys.join(", ")}"

doc.fetch("write_files", []).each do |wf|
  inner = begin
    YAML.safe_load(wf["content"])
  rescue => e
    abort "[2] #{wf["path"]}: パース FAIL  #{e.message}"
  end
  puts "[2] #{wf["path"]}: パース OK"

  next unless wf["path"].include?("netplan")
  eth = (inner["network"] || {})["ethernets"]
  abort "[3] 構造 FAIL: network.ethernets が Hash でない (#{eth.inspect})" unless eth.is_a?(Hash)

  defaults = 0
  eth.each do |nic, cfg|
    abort "[3] 構造 FAIL: #{nic} に addresses がない" unless cfg.is_a?(Hash) && cfg["addresses"]
    defaults += (cfg["routes"] || []).count { |r| r["to"] == "default" }
    puts "[3] #{nic}: addresses=#{cfg["addresses"].inspect}"
  end
  abort "[3] 構造 FAIL: デフォルトルートが #{defaults} 本" unless defaults == 1
  puts "[3] 構造 OK"
end'
```

- 層1: 外側 cloud-config のパース
- 層2: `content` 内の netplan のパース
- 層3: **構造の検査**。`ethernets:` と `eth0:` を同じ深さに書くとパースは通るが
  `ethernets` は空になる。キー名の打ち間違い（`erthernets` / `addreses`）も
  YAML としては妥当なので、この層でしか捕まらない

### 層4 — `terraform plan`

`templatefile()` は渡されないキーを参照するとエラーになる。
**変数名の打ち間違いはここでしか検出できない**（手元のスクリプトは `${...}` を潰しているため）。
逆に plan は YAML の中身を検証できない。両方必要。

### 層5 — VM 上

```bash
cloud-init status --long                     # done / error / running
sudo cloud-init schema --system --annotate   # 行番号つき文法チェック
sudo netplan generate                        # 適用せず検証のみ
ip -br addr && ip route
sudo cat /var/log/cloud-init-output.log      # runcmd の実行結果
```

`netplan generate` は設定を適用しないので、壊れた設定で自分の接続を切る心配がない。
コマンド名のタイポ（`netplan aplly` など）は層1〜4を全て通過し、
`cloud-init-output.log` にしか現れない。

---

## 7. 運用上の注意

### 「作成時1回限りの副作用」に注意する

`disk_edit_parameter` はサーバ作成時に一度だけ走る副作用で、state に追跡されない。
適用されなくてもエラーが出ず、`plan` は収束済みと表示する。

この性質のせいで、次の事故が起きた。

> `source_archive_id`（ディスク側の属性）だけを変更 → ディスクのみ置換され、
> サーバは in-place update → サーバが再作成されないため新しいディスクに修正処理が当たらない。
> `terraform plan` は `No changes`。実機は全台到達不能。

診断の決め手は API の `CreatedAt` 突き合わせで、**サーバがディスクより 8 分古い**ことに気づいた点だった。

`user_data` は state 追跡される属性なのでこの弱点は無い。ただし
**初回ブート済みのディスクを再利用すると cloud-init が再実行されない**という同型の罠が残る。
アーカイブを変えずに `user_data` だけ変更する場合、plan にディスクの replace が出ないので、
必要なら `-replace` でディスクも明示的に作り直すこと。

### destroy はコードを書き換えない

設定に起因する不具合は destroy / apply では直らない。同じ結果が再生産されるだけである。
加えて `sakura_internet` が破棄されてグローバル IP ブロックが変わるため、混乱が増える。

### VM を作り直すと SSH ホスト鍵が変わる

```
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

```bash
ssh-keygen -R <ip>
```

### control から agent への SSH

秘密鍵は手元の Mac にしかない（公開鍵のみ cloud-config で配布）。
control に秘密鍵を置かず、エージェント転送を使う。

```bash
ssh-add --apple-use-keychain ~/.ssh/helmes
ssh -A ubuntu@<control の global IP>
```

Ansible を control で回すときも同じ経路を使う。

---

## 8. 未完了の作業

### 小物

- `locals.tf` の `control` の `disk_size` が `var.disk_size_proxy` を参照している
  （`var.disk_size_control` が正しい。デフォルトが両方 40 のため現状は影響が出ない）
- `ssh_key.tf` の `sakura_ssh_key.main` が未参照。公開鍵は cloud-config 経由になったため削除可
- ファイル名 `terrafomrm.tf` の typo
- `agent_number` / `global_netmask` / `private_netmask` に `type` 未指定
- リモート backend 未設定（state はローカル）

### コンソール用パスワード（ブレークグラス）

現在 `lock_passwd: true` かつ `ssh_pwauth: false` のため、**SSH が通らなくなると
VNC コンソールにも入れず、中を確認する手段が無い**。実際にこの状態で
「原因を確認できないまま作り直す」ループに陥った。

`lock_passwd: false` と `passwd: <SHA-512ハッシュ>` を追加すれば、
`ssh_pwauth: false` を維持したまま（SSH は鍵のみのまま）コンソールログインだけ有効にできる。
VNC はコントロールパネルの認証の内側にあり、インターネットに露出しない。

```bash
openssl passwd -6        # ハッシュ生成
```

ハッシュは `var.console_password_hash`（`sensitive = true`）として
`secret.auto.tfvars` に置く。`user_data` は state に平文で保存される点に留意。

### proxy の NAT / squid

agent と log のデフォルトルートは proxy に向いているが、proxy 側の転送設定が未実装のため
外向き通信はまだ成立しない。NAT なら簡単、squid ならトークン使用量の可視化という
hermes 本来の目的に効く。Ansible の担当範囲。

### パケットフィルタの分割

現在 `private_in` という単一フィルタが、agent / log の ens3 と
control / monitor / proxy の ens4 という性格の違う7つの NIC すべてに適用されている。
squid のポートを足すとプライベート網の全ホストで開く。

| フィルタ | 適用先 | 許可する受信 |
|---|---|---|
| `global_in` | control/monitor/proxy の ens3 | icmp、22/tcp from `allowed_ssh_cidr`、ephemeral、deny all |
| `agent_in` | agent / log の ens3 | icmp、22/tcp from control、ephemeral、deny all |
| `proxy_private_in` | proxy の ens4 | 上記 + 3128/tcp from 192.168.100.0/24 |
| `infra_private_in` | control/monitor の ens4 | icmp、ephemeral、deny all |

### ログ転送・監視スクレイプのポート設計

使用するソフトウェアが決まってから、対応するフィルタに追加する。
