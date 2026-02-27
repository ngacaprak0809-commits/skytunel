#!/bin/bash
# Restore AutoScript Xray backup created by backup.sh
# Usage: restore.sh /path/to/backup.tar.gz
#        restore.sh tg:<file_id>    (unduh dari Telegram menggunakan bot)
# Jika argumen kosong dan BACKUP_TG_TOKEN/BACKUP_TG_CHAT_ID terisi,
# script akan mengambil dokumen terakhir di chat tersebut.
set -uo pipefail

# Default Telegram credentials (overrideable by env)
BACKUP_TG_TOKEN="${7995056072:AAHNM6-DpKyHhhtfqvLTM79Uqiwt5-FXeqE}"
BACKUP_TG_CHAT_ID="${6362098219}"

backup_arg="${1:-}"
tmp_download=""

# Unduh dari Telegram jika diminta
download_from_telegram() {
  local file_id="$1"
  tmp_download=$(mktemp /tmp/backup-restore-XXXX.tar.gz)
  TG_TOKEN="${BACKUP_TG_TOKEN:-}"
  TG_CHAT_ID="${BACKUP_TG_CHAT_ID:-}"
  if [ -z "$TG_TOKEN" ]; then
    echo "BACKUP_TG_TOKEN belum diset."
    exit 1
  fi

  python3 - <<'PY'
import os, sys, json, urllib.request

token = os.environ["BACKUP_TG_TOKEN"]
chat_id = os.environ.get("BACKUP_TG_CHAT_ID")
file_id = os.environ.get("TG_FILE_ID")
out = os.environ["TMP_OUT"]

def latest_file_id():
    url = f"https://api.telegram.org/bot{token}/getUpdates"
    with urllib.request.urlopen(url) as r:
        data = json.load(r)
    docs = []
    for upd in data.get("result", []):
        msg = upd.get("message") or upd.get("channel_post") or {}
        if chat_id and str(msg.get("chat", {}).get("id")) != chat_id:
            continue
        if "document" in msg:
            docs.append(msg["document"]["file_id"])
    if not docs:
        sys.exit("NO_DOC")
    return docs[-1]

if not file_id:
    file_id = latest_file_id()

# Get file path
with urllib.request.urlopen(f"https://api.telegram.org/bot{token}/getFile?file_id={file_id}") as r:
    data = json.load(r)
file_path = data["result"]["file_path"]
url = f"https://api.telegram.org/file/bot{token}/{file_path}"
urllib.request.urlretrieve(url, out)
print(out)
PY
  return $?
}

if [ -z "$backup_arg" ] || [[ "$backup_arg" =~ ^tg: ]]; then
  TG_FILE_ID="${backup_arg#tg:}"
  export BACKUP_TG_TOKEN BACKUP_TG_CHAT_ID TG_FILE_ID TMP_OUT
  TMP_OUT=$(mktemp /tmp/backup-restore-XXXX.tar.gz)
  if ! download_from_telegram "$TG_FILE_ID"; then
    echo "Gagal mengambil backup dari Telegram."
    exit 1
  fi
  backup_file="$TMP_OUT"
elif [ -f "$backup_arg" ]; then
  backup_file="$backup_arg"
else
  echo "File backup tidak ditemukan: $backup_arg"
  exit 1
fi

if [ ! -s "$backup_file" ]; then
  echo "File backup kosong atau tidak berhasil diunduh: $backup_file"
  exit 1
fi

if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
  echo "File bukan arsip .tar.gz yang valid."
  exit 1
fi

echo "Menghentikan layanan terkait..."
for svc in xray vmess-grpc vless-grpc udp-custom client-sldns server-sldns ws-dropbear ws-stunnel; do
  systemctl stop "$svc" 2>/dev/null || true
done

echo "Menjalankan restore ke root (/)..."
if ! tar -xzf "$backup_file" -C /; then
  echo "Gagal mengekstrak arsip backup."
  exit 1
fi

# Pastikan permission file akun benar
if [ -f /etc/shadow ]; then chmod 600 /etc/shadow; fi
if [ -f /etc/gshadow ]; then chmod 600 /etc/gshadow; fi
if [ -f /etc/passwd ]; then chmod 644 /etc/passwd; fi
if [ -f /etc/group ]; then chmod 644 /etc/group; fi

if [ -f /etc/iptables.up.rules ]; then
  echo "Memulihkan aturan iptables..."
  iptables-restore < /etc/iptables.up.rules 2>/dev/null || true
  netfilter-persistent save 2>/dev/null || true
  netfilter-persistent reload 2>/dev/null || true
fi

echo "Memuat ulang daemon & menyalakan layanan..."
systemctl daemon-reload
for svc in nginx sshd xray vmess-grpc vless-grpc udp-custom client-sldns server-sldns ws-dropbear ws-stunnel openvpn stunnel4; do
  systemctl restart "$svc" 2>/dev/null || true
done

echo "Restore selesai. Periksa kembali domain/sertifikat dan pastikan layanan aktif."

[ -n "$tmp_download" ] && rm -f "$tmp_download"
