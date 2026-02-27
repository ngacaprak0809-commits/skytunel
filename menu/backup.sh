#!/bin/bash
# Backup AutoScript Xray configs, users, and services
# Usage: backup.sh [output_dir]
# Upload opsi:
#   - Isi token & chat id di bawah (TELEGRAM_BOT_TOKEN_DEFAULT / TELEGRAM_CHAT_ID_DEFAULT)
#     atau lewat env BACKUP_TG_TOKEN / BACKUP_TG_CHAT_ID.
#   - Jika terisi, backup akan dikirim via Telegram bot (sendDocument).
set -uo pipefail

OUT_DIR=${1:-/root}
timestamp=$(date +%F-%H%M%S)
outfile="$OUT_DIR/backup-autoscript-$timestamp.tar.gz"
# Telegram (opsional)
TELEGRAM_BOT_TOKEN_DEFAULT="7995056072:AAHNM6-DpKyHhhtfqvLTM79Uqiwt5-FXeqE"
TELEGRAM_CHAT_ID_DEFAULT="6362098219"
BACKUP_TG_TOKEN=${BACKUP_TG_TOKEN:-$TELEGRAM_BOT_TOKEN_DEFAULT}
BACKUP_TG_CHAT_ID=${BACKUP_TG_CHAT_ID:-$TELEGRAM_CHAT_ID_DEFAULT}

add_if_exists() {
  [ -e "$1" ] && include+=( "$1" )
}

include=()
mkdir -p "$OUT_DIR"

echo "Menyiapkan daftar file untuk dibackup..."
# Core configs
add_if_exists "/etc/xray"
add_if_exists "/etc/v2ray"
add_if_exists "/etc/ssh/sshd_config"
add_if_exists "/etc/ssh/sshd_config.d"
add_if_exists "/etc/openvpn"
add_if_exists "/etc/slowdns"
add_if_exists "/etc/ipsec.d"
add_if_exists "/etc/ppp"
add_if_exists "/etc/iptables.up.rules"
add_if_exists "/home/vps/public_html"
add_if_exists "/home/re_otm"
add_if_exists "/etc/cron.d/xp_otm"
add_if_exists "/root/udp"
add_if_exists "/root/nsdomain"
# System accounts (needed agar user SSH ikut tersalin)
add_if_exists "/etc/passwd"
add_if_exists "/etc/shadow"
add_if_exists "/etc/group"
add_if_exists "/etc/gshadow"
# Logs create user (agar daftar akun mudah dilihat setelah restore)
add_if_exists "/etc/log-create-ssh.log"
add_if_exists "/etc/log-create-vless.log"
add_if_exists "/etc/log-create-vmess.log"
add_if_exists "/etc/log-create-trojan.log"

# Domain & certificates (acme)
if [ -f /etc/xray/domain ]; then
  domain=$(cat /etc/xray/domain)
  add_if_exists "/root/.acme.sh/${domain}_ecc"
  add_if_exists "/etc/xray/domain"
  add_if_exists "/etc/xray/scdomain"
  add_if_exists "/root/domain"
fi

# Systemd units for custom services
add_if_exists "/etc/systemd/system/udp-custom.service"
add_if_exists "/etc/systemd/system/vmess-grpc.service"
add_if_exists "/etc/systemd/system/vless-grpc.service"
add_if_exists "/etc/systemd/system/xolpanel.service"
add_if_exists "/etc/systemd/system/client-sldns.service"
add_if_exists "/etc/systemd/system/server-sldns.service"
add_if_exists "/etc/systemd/system/ws-dropbear.service"
add_if_exists "/etc/systemd/system/ws-stunnel.service"

# Menu binaries (only if present)
for f in /usr/bin/menu /usr/bin/m-* /usr/bin/xray-renew /usr/bin/addgrpc /usr/bin/delgrpc /usr/bin/renewgrpc /usr/bin/cekgrpc; do
  [ -e "$f" ] && include+=( "$f" )
done

if [ "${#include[@]}" -eq 0 ]; then
  echo "Tidak ada file/dir yang ditemukan untuk dibackup."
  exit 1
fi

echo "Membuat arsip $outfile ..."
tar -czf "$outfile" "${include[@]}"
echo "Backup selesai dibuat di: $outfile"

# Kirim via Telegram (opsional)
if [ -n "$BACKUP_TG_TOKEN" ] && [ -n "$BACKUP_TG_CHAT_ID" ]; then
  echo "Mengirim backup via Telegram bot..."
  if command -v curl >/dev/null 2>&1; then
    tg_url="https://api.telegram.org/bot${BACKUP_TG_TOKEN}/sendDocument"
    resp=$(curl -s -X POST "$tg_url" \
      -F chat_id="$BACKUP_TG_CHAT_ID" \
      -F document=@"$outfile" \
      -F caption="Backup AutoScript $(basename "$outfile")")
    if echo "$resp" | grep -q '"ok":true'; then
      echo "Backup terkirim via Telegram."
    else
      echo "Gagal kirim via Telegram: $resp"
    fi
  else
    echo "curl tidak tersedia; Telegram dilewati."
  fi
fi

exit 0
