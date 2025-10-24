#!/usr/bin/env bash
set -euo pipefail
set -x

DATA_DIR="/data"
CREDENTIALS_DIR="${DATA_DIR}/security"
BRIDGE_DATA_DIR="${DATA_DIR}/bridge"

export PASSWORD_STORE_DIR="${CREDENTIALS_DIR}/pass"
export GNUPGHOME="${CREDENTIALS_DIR}/gnupg"

export XDG_DATA_HOME="${BRIDGE_DATA_DIR}/data"
export XDG_CONFIG_HOME="${BRIDGE_DATA_DIR}/config"
export XDG_CACHE_HOME="${BRIDGE_DATA_DIR}/cache"

BRIDGE_SMTP_PORT="${BRIDGE_SMTP_PORT:-1025}"
BRIDGE_IMAP_PORT="${BRIDGE_IMAP_PORT:-1143}"
SMTP_PORT="${SMTP_PORT:-8025}"
IMAP_PORT="${IMAP_PORT:-8143}"

if [ ! -d "${GNUPGHOME}" ]; then
  mkdir -p "${CREDENTIALS_DIR}"
  mkdir -p "${GNUPGHOME}"
  chmod -R 700 "${CREDENTIALS_DIR}"

  gpg --generate-key --batch << EOF
%no-protection
%echo Generating a basic OpenPGP key
Key-Type: RSA
Key-Length: 2048
Name-Real: ProtonMailBridge
Expire-Date: 0
%commit
%echo done
EOF

else
  # start GPG agent
  gpg-agent --daemon --allow-preset-passphrase
fi

if [ ! -d "${PASSWORD_STORE_DIR}" ]; then
  pass init ProtonMailBridge
  sleep 1
fi

# Proton mail bridge listen only on 127.0.0.1 interface, we need to forward TCP traffic on SMTP and IMAP ports:
socat TCP-LISTEN:"$SMTP_PORT",fork TCP:127.0.0.1:"$BRIDGE_SMTP_PORT" &
socat TCP-LISTEN:"$IMAP_PORT",fork TCP:127.0.0.1:"$BRIDGE_IMAP_PORT" &

if [ "$#" -eq 0 ]; then
  # Start a default Proton Mail Bridge on a fake tty, so it won't stop because of EOF
  echo ">>> Starting bridge"
  rm -f commands
  mkfifo commands
  tail -f commands | /usr/bin/bridge --cli

  echo ">>> done"
else
  /usr/bin/bridge "$@"
fi
