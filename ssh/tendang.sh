#!/bin/bash

# Default: 2 IP unik per akun (bisa diubah via argumen pertama)
MAX=${1:-2}
LOG=""
SERVICE=""

if [ -e "/var/log/auth.log" ]; then
    LOG="/var/log/auth.log"
    SERVICE="ssh"
elif [ -e "/var/log/secure" ]; then
    LOG="/var/log/secure"
    SERVICE="sshd"
else
    echo "Tidak menemukan auth log (auth.log/secure)."
    exit 1
fi

# Muat daftar user dengan home di /home
mapfile -t username_list < <(awk -F: '$6 ~ /^\\/home\\// {print $1}' /etc/passwd)

# Ambil log login SSH yang sukses
grep -i sshd "$LOG" | grep -i "Accepted password for" > /tmp/log-ssh.txt

# PID sesi aktif (sshd privilege separation)
mapfile -t proc < <(ps aux | grep "\\[priv\\]" | awk '{print $2}')

declare -A user_ips         # user -> "ip1 ip2 ..."
declare -A user_ip_pids     # "user|ip" -> "pid pid"

for PID in "${proc[@]}"; do
    line=$(grep "sshd\[$PID\]" /tmp/log-ssh.txt | tail -n1)
    [ -z "$line" ] && continue
    USER=$(echo "$line" | awk '{print $9}')
    IP=$(echo "$line"   | awk '{print $11}')
    [ -z "$USER" ] || [ -z "$IP" ] && continue

    key="${USER}|${IP}"
    user_ip_pids[$key]="${user_ip_pids[$key]} $PID"

    if [[ -z "${user_ips[$USER]}" ]]; then
        user_ips[$USER]="$IP"
    else
        # Tambahkan IP hanya jika belum ada
        if ! grep -qw "$IP" <<<"${user_ips[$USER]}"; then
            user_ips[$USER]="${user_ips[$USER]} $IP"
        fi
    fi
done

hit=0
log_file="/root/log-limit.txt"

for user in "${username_list[@]}"; do
    ips=(${user_ips[$user]})
    count=${#ips[@]}
    if (( count > MAX )); then
        date_now=$(date +"%Y-%m-%d %H:%M:%S")
        echo "$date_now - $user - $count" | tee -a "$log_file"
        # Kill semua sesi dari IP yang melebihi kuota (mulai IP ke-(MAX+1))
        for ip in "${ips[@]:MAX}"; do
            kill ${user_ip_pids["$user|$ip"]} 2>/dev/null
        done
        hit=$((hit + 1))
    fi
done

# Restart SSH jika ada sesi yang dikill
if (( hit > 0 )); then
    service "$SERVICE" restart > /dev/null 2>&1
fi
