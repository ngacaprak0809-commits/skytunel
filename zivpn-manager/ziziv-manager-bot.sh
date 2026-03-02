#!/bin/bash
# ============================
# ZIVPN Full Installer All-in-One
# Manager + API + Telegram Bot
# Ready to run via SFTP
# Author: Harun & GPT-5
# ============================

# ============================
# 1・鞘Ε Pastikan dependency
# ============================
echo "Checking dependencies..."
deps=(jq curl vnstat socat openssl)
for cmd in "${deps[@]}"; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "Installing $cmd..."
    apt update && apt install -y $cmd
  fi
done

# ============================
# 2・鞘Ε Setup folder & files
# ============================
mkdir -p /etc/zivpn
CONFIG_FILE="/etc/zivpn/config.json"
META_FILE="/etc/zivpn/accounts_meta.json"

[ ! -f "$CONFIG_FILE" ] && echo '{"auth":{"config":[]}, "listen":":5667"}' > "$CONFIG_FILE"
[ ! -f "$META_FILE" ] && echo '{"accounts":[]}' > "$META_FILE"

# ============================
# 2・鞘Ε.1 Setup ENV (BOT & API)
# ============================
ENV_FILE="/etc/zivpn/bot.env"

if [ ! -f "$ENV_FILE" ]; then
cat <<'EOF' > "$ENV_FILE"
# ============================
# ZIVPN ENV CONFIG
# ============================

# Telegram
BOT_TOKEN=ISI_TOKEN_BOT
ADMIN_ID=ISI_ADMIN_ID

# API
API_KEY=$(openssl rand -hex 16)
EOF

chmod 600 "$ENV_FILE"
fi


# ============================
# 3・鞘Ε Manager Script
# ============================
MANAGER_SCRIPT="/usr/local/bin/zivpn-manager.sh"
SHORTCUT="/usr/local/bin/zivpn-manager"

rm -f "$MANAGER_SCRIPT" "$SHORTCUT"

cat <<'EOF' > "$MANAGER_SCRIPT"
#!/bin/bash
CONFIG_FILE="/etc/zivpn/config.json"
META_FILE="/etc/zivpn/accounts_meta.json"
SERVICE_NAME="zivpn.service"

[ ! -f "$META_FILE" ] && echo '{"accounts":[]}' > "$META_FILE"

sync_accounts() {
    for pass in $(jq -r ".auth.config[]" "$CONFIG_FILE"); do
        exists=$(jq -r --arg u "$pass" ".accounts[]?.user // empty | select(.==\$u)" "$META_FILE")
        [ -z "$exists" ] && jq --arg user "$pass" --arg exp "2099-12-31" \
            ".accounts += [{\"user\":\$user,\"expired\":\$exp}]" "$META_FILE" > /tmp/meta.tmp && mv /tmp/meta.tmp "$META_FILE"
    done
}

auto_remove_expired() {
    today=$(date +%s)
    jq -c ".accounts[]" "$META_FILE" | while read -r acc; do
        user=$(echo "$acc" | jq -r ".user")
        exp=$(echo "$acc" | jq -r ".expired")
        exp_epoch=$(date -d "$exp" +%s 2>/dev/null)

        if [ "$today" -ge "$exp_epoch" ]; then
            jq --arg user "$user" '.auth.config |= map(select(. != $user))' "$CONFIG_FILE" > /tmp/config.tmp && mv /tmp/config.tmp "$CONFIG_FILE"
            jq --arg user "$user" '.accounts |= map(select(.user != $user))' "$META_FILE" > /tmp/meta.tmp && mv /tmp/meta.tmp "$META_FILE"
            systemctl restart "$SERVICE_NAME" >/dev/null 2>&1
            echo "Auto remove expired: $user"
        fi
    done
}

backup_accounts() {
    BACKUP_DIR="/etc/zivpn"
    cp "$CONFIG_FILE" "$BACKUP_DIR/backup_config.json"
    cp "$META_FILE" "$BACKUP_DIR/backup_meta.json"
    echo "Backup selesai (lokal)."
    read -rp "Enter..." enter
    menu
}

restore_accounts() {
    BACKUP_DIR="/etc/zivpn"
    if [ ! -f "$BACKUP_DIR/backup_config.json" ] || [ ! -f "$BACKUP_DIR/backup_meta.json" ]; then
        echo "Backup tidak ada!"
        read -rp "Enter..." enter
        menu
    fi
    cp "$BACKUP_DIR/backup_config.json" "$CONFIG_FILE"
    cp "$BACKUP_DIR/backup_meta.json" "$META_FILE"
    systemctl restart "$SERVICE_NAME"
    echo "Restore selesai."
    read -rp "Enter..." enter
    menu
}

edit_bot_env() {
    ENV_FILE="/etc/zivpn/bot.env"

    if [ ! -f "$ENV_FILE" ]; then
        echo "笶・File bot.env tidak ditemukan!"
        read -rp "Enter..." enter
        menu
    fi

    source "$ENV_FILE"

    clear
    echo "===================================="
    echo "   KONFIGURASI BOT & API ZIVPN"
    echo "===================================="
    echo "1) Ubah BOT TOKEN"
    echo "2) Ubah ADMIN ID"
    echo "3) Generate API KEY baru"
    echo "0) Kembali"
    echo "===================================="
    read -rp "Pilih: " opt

    case "$opt" in
        1)
            read -rp "BOT TOKEN baru: " NEW_TOKEN
            [ -z "$NEW_TOKEN" ] && edit_bot_env
            sed -i "s|^BOT_TOKEN=.*|BOT_TOKEN=$NEW_TOKEN|" "$ENV_FILE"
            echo "笨・BOT TOKEN berhasil diubah"
        ;;
        2)
            read -rp "ADMIN ID baru: " NEW_ADMIN
            [ -z "$NEW_ADMIN" ] && edit_bot_env
            sed -i "s|^ADMIN_ID=.*|ADMIN_ID=$NEW_ADMIN|" "$ENV_FILE"
            echo "笨・ADMIN ID berhasil diubah"
        ;;
        3)
            NEW_KEY=$(openssl rand -hex 16)
            sed -i "s|^API_KEY=.*|API_KEY=$NEW_KEY|" "$ENV_FILE"
            echo "笨・API KEY baru berhasil dibuat:"
            echo "$NEW_KEY"
        ;;
        0)
            menu
        ;;
        *)
            edit_bot_env
        ;;
    esac

    echo ""
    echo "売 Restart API service..."
    systemctl restart zivpn-api.service

    read -rp "Enter..." enter
    menu
}

menu() {
    clear
    sync_accounts

    echo "===================================="
    echo "     ZIVPN UDP ACCOUNT MANAGER"
    echo "===================================="

    VPS_IP=$(curl -s ifconfig.me || echo "Tidak ditemukan")
    echo "IP VPS       : ${VPS_IP}"

    ISP_NAME=$(curl -s https://ipinfo.io/org | sed 's/^[^ ]* //')
    echo "ISP          : ${ISP_NAME}"

    NET_IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)

    BW_DAILY_DOWN=$(vnstat -i "$NET_IFACE" --json | jq -r '.interfaces[0].traffic.day[-1].rx')
    BW_DAILY_UP=$(vnstat -i "$NET_IFACE" --json | jq -r '.interfaces[0].traffic.day[-1].tx')

    BW_MONTH_DOWN=$(vnstat -i "$NET_IFACE" --json | jq -r '.interfaces[0].traffic.month[-1].rx')
    BW_MONTH_UP=$(vnstat -i "$NET_IFACE" --json | jq -r '.interfaces[0].traffic.month[-1].tx')

# Konversi dari byte ke MB
    BW_DAILY_DOWN=$(awk -v b=$BW_DAILY_DOWN 'BEGIN {printf "%.2f MB", b/1024/1024}')
    BW_DAILY_UP=$(awk -v b=$BW_DAILY_UP 'BEGIN {printf "%.2f MB", b/1024/1024}')
    BW_MONTH_DOWN=$(awk -v b=$BW_MONTH_DOWN 'BEGIN {printf "%.2f MB", b/1024/1024}')
    BW_MONTH_UP=$(awk -v b=$BW_MONTH_UP 'BEGIN {printf "%.2f MB", b/1024/1024}')

    echo "Daily        : D $BW_DAILY_DOWN | U $BW_DAILY_UP"
    echo "Monthly      : D $BW_MONTH_DOWN | U $BW_MONTH_UP"
    echo "===================================="

    echo "1) Lihat akun UDP"
    echo "2) Tambah akun baru"
    echo "3) Hapus akun"
    echo "4) Perpanjang akun"
    echo "5) Restart layanan"
    echo "6) Status VPS"
    echo "7) Backup"
    echo "8) Restore akun"
    echo "9) Konfigurasi Bot & API"
    echo "0) Keluar"
    echo "===================================="
    read -rp "Pilih: " choice

    case $choice in
    1) list_accounts ;;
    2) add_account ;;
    3) delete_account ;;
    4) extend_account ;;
    5) restart_service ;;
    6) vps_status ;;
    7) backup_accounts ;;
    8) restore_accounts ;;
    9) edit_bot_env ;;
    0) exit 0 ;;
    *) menu ;;
esac
}

list_accounts() {
    today=$(date +%s)
    jq -c ".accounts[]" "$META_FILE" | while read -r acc; do
        user=$(echo "$acc" | jq -r ".user")
        exp=$(echo "$acc" | jq -r ".expired")
        exp_ts=$(date -d "$exp" +%s 2>/dev/null)
        status="Aktif"
        [ "$today" -ge "$exp_ts" ] && status="Expired"
        echo "窶｢ $user | Exp: $exp | $status"
    done
    read -rp "Enter..." enter
    menu
}

add_account() {
    read -rp "Password baru: " new_pass
    [ -z "$new_pass" ] && menu

    # Cek apakah akun sudah ada
    exists=$(jq -r --arg u "$new_pass" '.auth.config[] | select(.==$u)' "$CONFIG_FILE")
    if [ -n "$exists" ]; then
        echo "笶・Akun $new_pass sudah ada!"
        read -rp "Tekan ENTER untuk kembali ke menu..." enter
        menu
    fi

    read -rp "Berlaku (hari): " days
    [[ -z "$days" ]] && days=3

    exp_date=$(date -d "+$days days" +%Y-%m-%d)

    jq --arg pass "$new_pass" '.auth.config |= . + [$pass]' "$CONFIG_FILE" > /tmp/conf.tmp && mv /tmp/conf.tmp "$CONFIG_FILE"
    jq --arg user "$new_pass" --arg expired "$exp_date" '.accounts += [{"user":$user,"expired":$expired}]' "$META_FILE" > /tmp/meta.tmp && mv /tmp/meta.tmp "$META_FILE"

    systemctl restart "$SERVICE_NAME"

    # Opsional: kirim notif akun baru ke Telegram
    # send_account_to_telegram "$new_pass" "$exp_date"

    echo "笨・Akun $new_pass ditambahkan."
    read -rp "Tekan ENTER untuk kembali ke menu..." enter
    menu
}

delete_account() {
    read -rp "Password hapus: " del_pass
    # Cek apakah akun ada
    exists=$(jq -r --arg u "$del_pass" '.auth.config[] | select(.==$u)' "$CONFIG_FILE")
    if [ -z "$exists" ]; then
        echo "笶・Akun $del_pass tidak ditemukan!"
    else
        jq --arg pass "$del_pass" '.auth.config |= map(select(. != $pass))' "$CONFIG_FILE" > /tmp/conf.tmp && mv /tmp/conf.tmp "$CONFIG_FILE"
        jq --arg pass "$del_pass" '.accounts |= map(select(.user != $pass))' "$META_FILE" > /tmp/meta.tmp && mv /tmp/meta.tmp "$META_FILE"
        systemctl restart "$SERVICE_NAME"
        echo "笨・Akun $del_pass sudah dihapus."
    fi
    read -rp "Tekan ENTER untuk kembali ke menu..." enter
    menu
}

extend_account() {
    read -rp "Password akun: " ext_user
    [ -z "$ext_user" ] && menu

    # Ambil expired lama
    OLD_EXP=$(jq -r --arg u "$ext_user" '.accounts[] | select(.user==$u) | .expired' "$META_FILE")

    if [ -z "$OLD_EXP" ] || [ "$OLD_EXP" = "null" ]; then
        echo "笶・Akun $ext_user tidak ditemukan!"
        read -rp "ENTER..." enter
        menu
    fi

    read -rp "Perpanjang (hari): " days
    [[ -z "$days" ]] && days=3

    TODAY=$(date +%Y-%m-%d)

    # Tentukan tanggal dasar
    if [[ "$OLD_EXP" < "$TODAY" ]]; then
        BASE_DATE="$TODAY"
    else
        BASE_DATE="$OLD_EXP"
    fi

    NEW_EXP=$(date -d "$BASE_DATE +$days days" +%Y-%m-%d)

    jq --arg u "$ext_user" --arg exp "$NEW_EXP" '
      .accounts |= map(
        if .user == $u then
          .expired = $exp
        else .
        end
      )
    ' "$META_FILE" > /tmp/meta.tmp && mv /tmp/meta.tmp "$META_FILE"

    systemctl restart "$SERVICE_NAME"

    echo "笨・Akun berhasil diperpanjang"
    echo "側 User        : $ext_user"
    echo "套 Exp lama    : $OLD_EXP"
    echo "套 Exp baru    : $NEW_EXP"

    read -rp "ENTER..." enter
    menu
}

restart_service() {
    systemctl restart "$SERVICE_NAME"
    sleep 1
    menu
}

vps_status() {
    echo "Uptime      : $(uptime -p)"
    echo "CPU Usage   : $(top -bn1 | grep Cpu | awk '{print $2 + $4 "%"}')"
    echo "RAM Usage   : $(free -h | awk '/Mem:/ {print $3 " / " $2}')"
    echo "Disk Usage  : $(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
    read -rp "Enter..." enter
    menu
}

menu
EOF

chmod +x "$MANAGER_SCRIPT"
echo -e "#!/bin/bash\nsudo $MANAGER_SCRIPT" > "$SHORTCUT"
chmod +x "$SHORTCUT"

# ============================
# 4・鞘Ε API Script & Service
# ============================
API_SCRIPT="/usr/local/bin/zivpn-api.sh"
cat <<'EOF' > "$API_SCRIPT"
#!/bin/bash

CONFIG="/etc/zivpn/config.json"
META="/etc/zivpn/accounts_meta.json"
SERVICE="zivpn.service"
IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
# Load ENV
ENV_FILE="/etc/zivpn/bot.env"
[ ! -f "$ENV_FILE" ] && { echo "ENV file not found"; exit 1; }
source "$ENV_FILE"

read request

CMD=$(echo "$request" | grep -oP '(?<=cmd=)[^& ]+')
KEY=$(echo "$request" | grep -oP '(?<=key=)[^& ]+')
USER=$(echo "$request" | grep -oP '(?<=user=)[^& ]+')
DAYS=$(echo "$request" | grep -oP '(?<=days=)[^& ]+')

[ -z "$DAYS" ] && DAYS=3

if [ "$KEY" != "$API_KEY" ]; then
  echo -e "HTTP/1.1 403 Forbidden\n\nInvalid API Key"
  exit 0
fi

echo -e "HTTP/1.1 200 OK"
echo "Content-Type: text/plain"
echo ""

case "$CMD" in

list)
  jq -c ".accounts[]" "$META" | while read -r acc; do
    user=$(echo "$acc" | jq -r ".user")
    exp=$(echo "$acc" | jq -r ".expired")
    echo "窶｢ $user | Exp: $exp"
  done
;;

add)
  if [ -z "$USER" ]; then
    echo "笶・Parameter user kosong"
    exit 0
  fi

  EXISTS=$(jq -r --arg u "$USER" '.auth.config[] | select(.==$u)' "$CONFIG")
  if [ -n "$EXISTS" ]; then
    echo "笶・Akun $USER sudah ada"
    exit 0
  fi

  EXP_DATE=$(date -d "+$DAYS days" +%Y-%m-%d)

  jq --arg user "$USER" '.auth.config += [$user]' "$CONFIG" > /tmp/conf.tmp && mv /tmp/conf.tmp "$CONFIG"
  jq --arg user "$USER" --arg exp "$EXP_DATE" '.accounts += [{"user":$user,"expired":$exp}]' "$META" > /tmp/meta.tmp && mv /tmp/meta.tmp "$META"

  systemctl restart "$SERVICE"
  echo "笨・Akun $USER berhasil ditambahkan (Exp: $EXP_DATE)"
;;

extend)
  if [ -z "$USER" ]; then
    echo "笶・Parameter user kosong"
    exit 0
  fi

  OLD_EXP=$(jq -r --arg user "$USER" '.accounts[] | select(.user==$user) | .expired' "$META")

  if [ -z "$OLD_EXP" ] || [ "$OLD_EXP" = "null" ]; then
    echo "笶・Akun $USER tidak ditemukan"
    exit 0
  fi

  TODAY=$(date +%Y-%m-%d)

  # Jika sudah expired, hitung dari hari ini
  if [[ "$OLD_EXP" < "$TODAY" ]]; then
    BASE_DATE="$TODAY"
  else
    BASE_DATE="$OLD_EXP"
  fi

  NEW_EXP=$(date -d "$BASE_DATE +$DAYS days" +%Y-%m-%d)

  jq --arg user "$USER" --arg exp "$NEW_EXP" '
    .accounts |= map(
      if .user == $user then
        .expired = $exp
      else .
      end
    )
  ' "$META" > /tmp/meta.tmp && mv /tmp/meta.tmp "$META"

  systemctl restart "$SERVICE"

  echo "笨・Akun $USER berhasil diperpanjang"
  echo "套 Expired lama : $OLD_EXP"
  echo "套 Expired baru : $NEW_EXP"
;;

delete)
  if [ -z "$USER" ]; then
    echo "笶・Parameter user kosong"
    exit 0
  fi

  EXISTS=$(jq -r --arg u "$USER" '.auth.config[] | select(.==$u)' "$CONFIG")
  if [ -z "$EXISTS" ]; then
    echo "笶・Akun $USER tidak ditemukan"
    exit 0
  fi

  jq --arg user "$USER" '.auth.config |= map(select(. != $user))' "$CONFIG" > /tmp/conf.tmp && mv /tmp/conf.tmp "$CONFIG"
  jq --arg user "$USER" '.accounts |= map(select(.user != $user))' "$META" > /tmp/meta.tmp && mv /tmp/meta.tmp "$META"

  systemctl restart "$SERVICE"
  echo "笨・Akun $USER berhasil dihapus"
;;

backup)
  cp "$CONFIG" /etc/zivpn/backup_config.json
  cp "$META" /etc/zivpn/backup_meta.json
  echo "笨・Backup BERHASIL"
;;

restore)
  if [ ! -f /etc/zivpn/backup_config.json ] || [ ! -f /etc/zivpn/backup_meta.json ]; then
    echo "笶・Backup tidak ditemukan"
    exit 0
  fi

  cp /etc/zivpn/backup_config.json "$CONFIG"
  cp /etc/zivpn/backup_meta.json "$META"
  systemctl restart "$SERVICE"
  echo "笨・Restore BERHASIL"
;;

restart)
  systemctl restart "$SERVICE"
  echo "笨・Service ZIVPN DIRESTART"
;;

status)
  echo "Uptime : $(uptime -p)"
  echo "CPU    : $(top -bn1 | grep Cpu | awk '{print $2 + $4 "%"}')"
  echo "RAM    : $(free -h | awk '/Mem:/ {print $3 " / " $2}')"
  echo "Disk   : $(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
;;

bandwidth)
  RX=$(vnstat -i "$IFACE" --json | jq -r '.interfaces[0].traffic.day[-1].rx')
  TX=$(vnstat -i "$IFACE" --json | jq -r '.interfaces[0].traffic.day[-1].tx')
  RX=$(awk -v b=$RX 'BEGIN {printf "%.2f MB", b/1024/1024}')
  TX=$(awk -v b=$TX 'BEGIN {printf "%.2f MB", b/1024/1024}')
  echo "Daily RX: $RX"
  echo "Daily TX: $TX"
;;

*)
  echo "Perintah tidak dikenal"
;;

esac
EOF

chmod +x "$API_SCRIPT"

cat <<EOF > /etc/systemd/system/zivpn-api.service
[Unit]
Description=ZIVPN API Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/socat TCP-LISTEN:7001,bind=127.0.0.1,reuseaddr,fork EXEC:/usr/local/bin/zivpn-api.sh
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn-api.service
systemctl restart zivpn-api.service

echo "Skipping Telegram bot install (disabled)."

# ============================
# 6・鞘Ε Auto-remove expired 24 jam nonstop
# ============================

echo "Membuat auto-remove expired script..."

cat <<'EOF' > /usr/local/bin/zivpn-autoremove.sh
#!/bin/bash
CONFIG_FILE="/etc/zivpn/config.json"
META_FILE="/etc/zivpn/accounts_meta.json"
SERVICE_NAME="zivpn.service"

today=$(date +%s)

jq -c ".accounts[]" "$META_FILE" | while read -r acc; do
    user=$(echo "$acc" | jq -r ".user")
    exp=$(echo "$acc" | jq -r ".expired")
    exp_epoch=$(date -d "$exp" +%s 2>/dev/null)

    if [ "$today" -ge "$exp_epoch" ]; then
        jq --arg user "$user" '.auth.config |= map(select(. != $user))' \
            "$CONFIG_FILE" > /tmp/config.tmp && mv /tmp/config.tmp "$CONFIG_FILE"

        jq --arg user "$user" '.accounts |= map(select(.user != $user))' \
            "$META_FILE" > /tmp/meta.tmp && mv /tmp/meta.tmp "$META_FILE"

        systemctl restart "$SERVICE_NAME" >/dev/null 2>&1
        echo "$(date) Auto removed expired user: $user" >> /var/log/zivpn-autoremove.log
    fi
done
EOF

chmod +x /usr/local/bin/zivpn-autoremove.sh

# Tambahkan cronjob 1 jam sekali
(crontab -l 2>/dev/null | grep -v 'zivpn-autoremove.sh'; echo "0 * * * * /usr/local/bin/zivpn-autoremove.sh >/dev/null 2>&1") | crontab -

# ============================
# 7・鞘Ε Selesai
# ============================
echo "===================================="
echo "笨・ZIVPN Manager + API + Bot Installed!"
echo "Manager: zivpn-manager"
echo "Bot Telegram: DISABLED"
echo "Auto-remove expired: ACTIVE"
echo "===================================="
echo ""
echo "噫 Membuka ZIVPN Manager..."
sleep 2
zivpn-manager

