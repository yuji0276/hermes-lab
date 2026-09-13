#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
SSH_KEY="${HOME}/.ssh/hermes"

test -f "${SSH_KEY}" || {
  echo "missing: ${SSH_KEY}" >&2
  exit 1
}
if ! ssh-add -l >/dev/null 2>&1; then
  echo "warning: ssh-agent に鍵が無い。パスフレーズを何度も聞かれるなら ssh-add ${SSH_KEY}" >&2
fi

# ホストのアドレスは Terraform を単一の出典にする。
# グローバル IP は destroy → apply のたびに変わるので直書きしない。
CONTROL_IP="$(terraform -chdir="${TERRAFORM_DIR}" output -json global_ips \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["control"])')"
PRIVATE_IPS="$(terraform -chdir="${TERRAFORM_DIR}" output -json private_ips)"

# jq に依存しないよう、JSON をそのまま埋め込んで組み立てる
TF_EXTRA_VARS="$(cat <<JSON
{
  "private_ips": ${PRIVATE_IPS}
}
JSON
)"

ANSIBLE_CONFIG="${SCRIPT_DIR}/ansible.cfg"
export ANSIBLE_CONFIG

ansible-playbook \
  -i "${CONTROL_IP}," \
  -e "ansible_user=ubuntu" \
  -e "ansible_ssh_private_key_file=${SSH_KEY}" \
  -e "${TF_EXTRA_VARS}" \
  "${SCRIPT_DIR}/bootstrap.yml"

ssh -o StrictHostKeyChecking=accept-new -i "${SSH_KEY}" "ubuntu@${CONTROL_IP}" \
  'cd /opt/hermes-ansible && ansible-playbook site.yml'
