#!/bin/bash

# Batasi maksimal IP aktif per akun Xray (VMess/VLESS/Trojan/SS)
# Pemakaian: bash xray/limit-ip.sh [MAX_IP]   # default 2

set -euo pipefail

MAX=${1:-2}
CONFIG="/etc/xray/config.json"
ACCESS="/var/log/xray/access.log"
LOGFILE="/root/log-limit-xray.txt"

if [ ! -f "$CONFIG" ] || [ ! -f "$ACCESS" ]; then
  echo "Config atau access log Xray tidak ditemukan."
  exit 1
fi

# Ambil daftar akun dari tag komentar ### user exp
mapfile -t USERS < <(grep -E '^###' "$CONFIG" | awk '{print $2}' | sort -u)
[[ ${#USERS[@]} -eq 0 ]] && exit 0

# IP aktif saat ini di proses xray (IPv4/IPv6)
mapfile -t ACTIVE_IPS < <(
  netstat -anp 2>/dev/null | grep ESTABLISHED | grep xray | awk '{print $5}' \
  | sed -E 's/^[[]//;s/[]]//;s/:([0-9]+)$//' | sort -u
)
[[ ${#ACTIVE_IPS[@]} -eq 0 ]] && exit 0

# Siapkan chain khusus agar tidak mengganggu aturan lain
prepare_chain() {
  local tool=$1
  $tool -N XRAYLIMIT 2>/dev/null || true
  if ! $tool -C INPUT -j XRAYLIMIT 2>/dev/null; then
    $tool -I INPUT 1 -j XRAYLIMIT
  fi
  $tool -F XRAYLIMIT
}

prepare_chain iptables
prepare_chain ip6tables

declare -A EXTRA_IPS

for user in "${USERS[@]}"; do
  # IP yang pernah dipakai user di access log
  mapfile -t LOG_IPS < <(grep -w "$user" "$ACCESS" | awk '{print $3}' | sed -E 's/:([0-9]+)$//' | sort -u)
  CURRENT=()
  for ip in "${LOG_IPS[@]}"; do
    if printf '%s\n' "${ACTIVE_IPS[@]}" | grep -Fxq "$ip"; then
      CURRENT+=("$ip")
    fi
  done

  if ((${#CURRENT[@]} > MAX)); then
    for ip in "${CURRENT[@]:MAX}"; do
      EXTRA_IPS["$ip"]=1
      echo "$(date +"%Y-%m-%d %H:%M:%S") - $user - $ip - over ${#CURRENT[@]}/$MAX" >> "$LOGFILE"
    done
  fi
done

# Tambahkan aturan drop hanya untuk IP yang melebihi kuota
for ip in "${!EXTRA_IPS[@]}"; do
  if [[ "$ip" == *:* ]]; then
    ip6tables -A XRAYLIMIT -s "$ip" -j DROP 2>/dev/null || true
  else
    iptables -A XRAYLIMIT -s "$ip" -j DROP 2>/dev/null || true
  fi
done

exit 0
