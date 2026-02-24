#!/bin/bash
# Restore AutoScript Xray backup created by backup.sh
# Usage: restore.sh /path/to/backup.tar.gz  OR restore.sh <gdrive|http> URL
set -uo pipefail

backup_file="${1:-}"
if [ -z "$backup_file" ]; then
  read -e -p "Masukkan path file backup (.tar.gz) atau link GDrive/HTTP: " backup_file
fi

tmp_download=""
tmp_dir=""

install_gdown() {
  if command -v gdown >/dev/null 2>&1; then
    return
  fi
  if ! command -v pip3 >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y python3-pip >/dev/null 2>&1 || true
  fi
  echo "Menginstall gdown..."
  if ! pip3 install --no-cache-dir gdown >/dev/null 2>&1; then
    echo "Install gdown gagal. Unduh manual file backup lalu jalankan ulang."
    exit 1
  fi
}

if [ -f "$backup_file" ]; then
  : # local file ok
elif [[ "$backup_file" =~ ^https?:// ]]; then
  if [[ "$backup_file" =~ drive.google.com/drive/folders ]]; then
    install_gdown
    tmp_dir=$(mktemp -d /tmp/backup-folder-XXXX)
    echo "Link folder Google Drive terdeteksi, mengunduh dengan gdown --folder..."
    if ! gdown --fuzzy --folder "$backup_file" -O "$tmp_dir" >/dev/null 2>&1; then
      echo "gdown gagal mengunduh folder. Pastikan link dapat diakses publik."
      exit 1
    fi
    backup_file=$(find "$tmp_dir" -maxdepth 2 -type f -name "*.tar.gz" | head -n1)
    if [ -z "$backup_file" ]; then
      echo "Tidak menemukan file .tar.gz di folder tersebut. Gunakan link langsung ke file backup."
      exit 1
    fi
  else
    tmp_download=$(mktemp /tmp/backup-restore-XXXX.tar.gz)
    echo "Mengunduh backup dari URL..."
    if command -v gdown >/dev/null 2>&1; then
      gdown --fuzzy "$backup_file" -O "$tmp_download" >/dev/null 2>&1 || true
    fi
    if [ ! -s "$tmp_download" ] && command -v rclone >/dev/null 2>&1; then
      echo "gdown tidak ada/ gagal, mencoba rclone copyurl..."
      rclone copyurl "$backup_file" "$tmp_download" >/dev/null 2>&1 || true
    fi
    if [ ! -s "$tmp_download" ]; then
      install_gdown
      if ! gdown --fuzzy "$backup_file" -O "$tmp_download"; then
        echo "gdown gagal mengunduh file."
        exit 1
      fi
    fi
    backup_file="$tmp_download"
  fi
else
  echo "File/link tidak ditemukan: $backup_file"
  exit 1
fi

if [ ! -s "$backup_file" ]; then
  echo "File backup kosong atau tidak berhasil diunduh: $backup_file"
  exit 1
fi

if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
  echo "File bukan arsip .tar.gz yang valid. Pastikan link langsung ke file backup, bukan halaman HTML/folder."
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
