#!/bin/bash

CONFIG="/etc/xray/config.json"
EXPIRED="/etc/xray/expired.txt"

if [ ! -f "$EXPIRED" ] || [ ! -s "$EXPIRED" ]; then
    echo "Tidak ada user Xray yang expired tercatat di $EXPIRED"
    exit 0
fi

echo "=== DAFTAR USER XRAY EXPIRED ==="
nl -ba "$EXPIRED"
echo "================================"
echo -n "Pilih nomor user yang mau di-renew: "
read num

if ! [[ "$num" =~ ^[0-9]+$ ]]; then
    echo "Input bukan angka."
    exit 1
fi

line=$(sed -n "${num}p" "$EXPIRED")
if [ -z "$line" ]; then
    echo "Nomor tidak valid."
    exit 1
fi

# Format: TANGGAL_LOG PROTO USER UUID EXPDATE
tgl_log=$(echo "$line" | awk '{print $1}')
proto=$(echo "$line"    | awk '{print $2}')
user=$(echo "$line"     | awk '{print $3}')
uuid=$(echo "$line"     | awk '{print $4}')
oldexp=$(echo "$line"   | awk '{print $5}')

echo ""
echo "User   : $user"
echo "Proto  : $proto"
echo "UUID   : $uuid"
echo "Expire lama : $oldexp"
echo ""

echo -n "Perpanjang berapa hari dari hari ini? : "
read days

if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo "Input hari harus angka."
    exit 1
fi

newexp=$(date -d "$days days" +"%Y-%m-%d") || {
    echo "Gagal hitung tanggal expire baru."
    exit 1
}

echo "Expire baru: $newexp"
echo ""

# Sisipkan ke config.json sesuai proto
case "$proto" in
    vmess)
        # VMESS WS (marker: #vmess)
        sed -i '/#vmess$/i\### '"$user $newexp"'\
      {\
        "id": "'"$uuid"'",\
        "alterId": 0\
      },' "$CONFIG"

        # VMESS gRPC (marker: #vmessgrpc)
        sed -i '/#vmessgrpc$/i\### '"$user $newexp"'\
      {\
        "id": "'"$uuid"'",\
        "alterId": 0\
      },' "$CONFIG"
        ;;

    vless)
        # VLESS WS (marker: #vless)
        sed -i '/#vless$/i\#& '"$user $newexp"'\
      {\
        "id": "'"$uuid"'"\
      },' "$CONFIG"

        # VLESS gRPC (marker: #vlessgrpc)
        sed -i '/#vlessgrpc$/i\#& '"$user $newexp"'\
      {\
        "id": "'"$uuid"'"\
      },' "$CONFIG"
        ;;

    trojan)
        # TROJAN WS (marker: #trojanws)
        sed -i '/#trojanws$/i\#! '"$user $newexp"'\
      {\
        "password": "'"$uuid"'"\
      },' "$CONFIG"

        # TROJAN gRPC (marker: #trojangrpc)
        sed -i '/#trojangrpc$/i\#! '"$user $newexp"'\
      {\
        "password": "'"$uuid"'"\
      },' "$CONFIG"
        ;;

    ss)
        # Shadowsocks WS (marker: #ssws)
        sed -i '/#ssws$/i\### '"$user $newexp"'\
      {\
        "method": "aes-128-gcm",\
        "password": "'"$uuid"'"\
      },' "$CONFIG"

        # Shadowsocks gRPC (marker: #ssgrpc)
        sed -i '/#ssgrpc$/i\### '"$user $newexp"'\
      {\
        "method": "aes-128-gcm",\
        "password": "'"$uuid"'"\
      },' "$CONFIG"
        ;;

    *)
        echo "Proto '$proto' tidak dikenali. Edit script kalau kamu pakai nama lain."
        exit 1
        ;;
esac

# Hapus baris dari expired.txt
sed -i "${num}d" "$EXPIRED"

# Restart Xray
systemctl restart xray

echo ""
echo "Berhasil renew:"
echo "- User   : $user"
echo "- Proto  : $proto"
echo "- UUID   : $uuid"
echo "- Expire : $newexp"
echo ""
echo "Data lama di $EXPIRED sudah dihapus."

exit 0
