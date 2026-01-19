#!/usr/bin/env bash
set -euo pipefail

mkdir -p /root/.ssh /work/logs
chmod 700 /root/.ssh

if [ -f /work/ssh/known_hosts ]; then
	cp /work/ssh/known_hosts /root/.ssh/known_hosts
	chmod 600 /root/.ssh/known_hosts
else
  echo "[WARN] /work/ssh/known_hosts not found."
fi

if [ -f /work/ssh/id_ed25519 ]; then
  cp /work/ssh/id_ed25519 /root/.ssh/id_ed25519
  chmod 600 /root/.ssh/id_ed25519
else
  echo "[ERROR] /work/ssh/id_ed25519 not found"
  exit 1
fi

export ANSIBLE_HOST_KEY_CHECKING=true
export ANSIBLE_STDOUT_CALLBACK=yaml

exec /usr/local/bin/supercronic /etc/crontab