# Ansible 実行手順

Terraform で VM を作った後、control を踏み台兼コントローラにして Ansible を流す手順。
設計の背景は `docs/infrastructure.md`、ディレクトリ構成の要点は `CLAUDE.md` の「### Ansible」を参照。

## 全体の流れ

```
Mac                          control (踏み台)                proxy / monitor / log / agent
───                          ────────────────                ────────────────────────────
deploy.sh
 ├ terraform output ─────┐
 │  (global_ips,         │
 │   private_ips)        │
 ├ bootstrap.yml ────────┼──▶ ansible-core を apt で導入
 │   (control 1 台へ)    │    ~/.ssh/hermes_control を配置
 │                       │    ssh-keyscan ──────────────────▶ 各ホストの host key を採取
 │                       │    /opt/hermes-ansible/ に ansible/ を配布
 │                       │    inventory/hosts.yml を生成
 └ ssh control ──────────┴──▶ ansible-playbook site.yml ────▶ proxy に squid ロールを適用
        ▲                              ▲
        鍵: hermes                      鍵: hermes_control
        (Mac → control)                (control → 各ホスト)
```

Mac から直接触るのは control だけ。agent / log はグローバル NIC を持たないので、
control 上の Ansible がプライベート側（192.168.100.0/24）から到達する。

## 鍵は 2 本を区間で使い分ける

| 鍵 | 区間 | パスフレーズ | 秘密鍵の置き場所 |
|---|---|---|---|
| `~/.ssh/hermes` | Mac → control（人が入る・`bootstrap.yml`） | あり | Mac のみ |
| `~/.ssh/hermes_control` | control 上の Ansible → 各ホスト（`site.yml`） | **無し** | Mac（原本）と control（`bootstrap.yml` がコピー） |

公開鍵は両方とも cloud-init で全 VM の `ubuntu` に登録される
（`var.ssh_public_key_path` / `var.control_ssh_public_key_path`）。
使い分けているのは「どこから接続するか」であって、接続先の側で鍵を区別しているわけではない。

分けている理由は 1 点。control 上の Ansible は TTY 無しで各ホストへ SSH するのでパスフレーズを聞けない。
`hermes` のパスフレーズを外せば 1 本で済むが、そうすると Mac 側の鍵が平文になる。
パスフレーズ無しの鍵は control 用に限定し、Mac → control の入口は `hermes` のまま守る、という配置。

`hermes_control` は VM に置く秘密鍵なので、control が侵害されると全 VM に入られる。
これは control を踏み台兼コントローラにした時点で構造的に避けられない。

### 初回のみ: `hermes_control` の作成

```bash
ssh-keygen -t ed25519 -N "" -C hermes-control -f ~/.ssh/hermes_control
```

公開鍵は cloud-init で VM に載るため、鍵を作った／作り直した後は**全ディスクの作り直し**が要る
（cloud-init は初回ブートでしか走らない。`docs/infrastructure.md` §7）。

```bash
terraform -chdir=terraform apply \
  -replace='sakura_disk.this["proxy"]' \
  -replace='sakura_disk.this["control"]' \
  -replace='sakura_disk.this["monitor"]' \
  -replace='sakura_disk.this["log"]' \
  -replace='sakura_disk.this["agent-1"]' \
  -replace='sakura_disk.this["agent-2"]' \
  -replace='sakura_disk.this["agent-3"]'
```

ディスクだけの replace なので `sakura_internet` は残り、グローバル IP は変わらない。
control の host key は変わるので、`deploy.sh` の前に `ssh-keygen -R <control の IP>` で
Mac の `~/.ssh/known_hosts` の古い行を消す。

## 事前条件

| 項目 | 確認方法 |
|---|---|
| VM が稼働している | `terraform -chdir=terraform output global_ips` で control の IP が出る |
| 手元から control:22 に届く | `nc -z -w 5 <control の IP> 22`。届かなければ `allowed_ssh_cidr` を確認 |
| Mac に Ansible がある | `ansible --version`（`brew install ansible`） |
| `hermes` がエージェントに入っている | `ssh-add -l`。無ければ `ssh-add ~/.ssh/hermes` |
| `hermes_control` がある | `ls ~/.ssh/hermes_control`。無ければ上記「初回のみ」 |
| `hermes_control.pub` が VM に載っている | 鍵を作った後にディスクを作り直したか。載っていないと 3 段目で `Permission denied` |

`~/.ssh/hermes` はパスフレーズ付きなので、`ssh-add` していないと接続のたびに聞かれる。
`deploy.sh` はエージェントに鍵が無いと警告を出すが止まりはしない。

## 実行

```bash
ssh-add ~/.ssh/hermes
ansible/deploy.sh
```

`deploy.sh` は Mac で動かす前提で、リポジトリ内のどこから叩いてもよい（自分の位置から `../terraform` を見る）。

### 1 段目: `terraform output` の読み取り

control のグローバル IP（`global_ips.control`）と全ホストのプライベート IP（`private_ips`）を拾う。
グローバル IP は destroy → apply のたびに変わるので、どこにも直書きしない。
state は手元の Mac にしか無いため、`terraform output` を読めるのはこの段だけ。

### 2 段目: `bootstrap.yml`（Mac → control）

`-i "<control の IP>,"` で control 1 台を対象にし、`private_ips` を `-e` で渡す。

1. `ansible-core` / `openssh-client` を apt で導入
2. `~/.ssh/hermes_control` を `/home/ubuntu/.ssh/hermes_control` にコピー（`no_log`）
3. control 以外の全ホストに `ssh-keyscan`（各 10 秒 × 最大 30 回リトライ）し、`known_hosts` に登録
4. `ansible/` ディレクトリを `/opt/hermes-ansible/` に配布
5. `templates/hosts.yml.j2` から `/opt/hermes-ansible/inventory/hosts.yml` を生成

### 3 段目: `site.yml`（control 上）

`ssh ubuntu@<control> 'cd /opt/hermes-ansible && ansible-playbook site.yml'`。
`site.yml` は `proxy.yml` を import し、`proxy_servers` グループに `squid` ロールを当てる。

## 動作確認

control に入って確認する。

```bash
ssh -i ~/.ssh/hermes ubuntu@<control の IP>

# インベントリが生成されているか
cat /opt/hermes-ansible/inventory/hosts.yml
cd /opt/hermes-ansible && ansible-inventory --graph

# 全ホストに届くか
ansible all -m ping

# proxy の squid
ssh 192.168.100.1 'systemctl is-active squid && sudo ss -ltnp | grep 3128'

# agent から proxy 経由で外に出られるか
ssh 192.168.100.11 'curl -sS -x http://192.168.100.1:3128 -o /dev/null -w "%{http_code}\n" https://example.com'
```

## 再実行

`bootstrap.yml` も `site.yml` も冪等なので、`ansible/` を変更したら `ansible/deploy.sh` を叩き直せばよい。
`squid.conf` に差分があるときだけ `restart squid` ハンドラが動く。

control 上で `site.yml` だけ流し直したいときは:

```bash
ssh -i ~/.ssh/hermes ubuntu@<control の IP> 'cd /opt/hermes-ansible && ansible-playbook site.yml'
```

ただし `/opt/hermes-ansible/` は `bootstrap.yml` が配布したコピーなので、Mac 側の `ansible/` を変えた場合は `deploy.sh` から流す。

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `Host key verification failed`（Mac → control） | destroy → apply で control の host key が変わった。`accept-new` は鍵の変更を拒否する | `ssh-keygen -R <control の IP>` で `~/.ssh/known_hosts` の古い行を消す |
| `Permission denied (publickey)`（Mac → control） | エージェントに鍵が無い、または `allowed_ssh_cidr` の外から接続している | `ssh-add ~/.ssh/hermes`。`nc -z <IP> 22` で届かなければフィルタの問題 |
| `Permission denied (publickey)`（control → 各ホスト、3 段目） | 対象ホストに `hermes_control.pub` が載っていない（鍵を作った／作り直した後にディスクを作り直していない） | `terraform apply -replace` で対象ディスクを作り直す |
| keyscan が `until` で延々リトライする | 対象ホストがまだ起動していない、またはパケットフィルタで 22 番が閉じている | `terraform/packet_filter.tf` で対象 NIC のフィルタを確認 |
| `apt` が失敗する | 対象ホストが外に出られない | control / proxy はグローバル NIC があるので通る。agent / log は proxy の squid が動くまで出られない |
| 手元で `ansible-playbook site.yml --syntax-check` すると inventory の警告が出る | インベントリは control 上にしか無い | 正常。無視してよい |
