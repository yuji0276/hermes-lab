#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"
SSH_KEY="${HOME}/.ssh/hermes"
CONTROL_SSH_KEY="${HOME}/.ssh/hermes_control"
# monitor の LiteLLM 用の鍵。bootstrap.yml が ansible/ ごと control に配る
SECRETS="${SCRIPT_DIR}/secrets.yml"

for f in "${SSH_KEY}" "${CONTROL_SSH_KEY}" "${SECRETS}"; do
  test -f "${f}" || {
    echo "missing: ${f}" >&2
    exit 1
  }
done
if ! ssh-add -l >/dev/null 2>&1; then
  echo "warning: ssh-agent に鍵が無い。パスフレーズを何度も聞かれるなら ssh-add ${SSH_KEY}" >&2
fi

CONTROL_IP="$(terraform -chdir="${TERRAFORM_DIR}" output -json global_ips \
  | python3 -c 'import json, sys; print(json.load(sys.stdin)["control"])')"
PRIVATE_IPS="$(terraform -chdir="${TERRAFORM_DIR}" output -json private_ips)"

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
