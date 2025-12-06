#!/bin/bash

EXPIRED_FILE="/etc/xray/expired.txt"
mkdir -p /etc/xray
touch "$EXPIRED_FILE"

##----- Auto Remove Vmess
data=( `cat /etc/xray/config.json | grep '^###' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
    exp=$(grep -w "^### $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    if [[ "$exp2" -le "0" ]]; then
        # ambil block client vmess
        block=$(sed -n "/^### $user $exp/,/^},{/p" /etc/xray/config.json)
        # ambil UUID (field \"id\")
        uuid=$(echo "$block" | grep -m1 '"id"' | cut -d'"' -f4)

        # simpan ke expired.txt kalau uuid ketemu
        if [ -n "$uuid" ]; then
            echo "$now vmess $user $uuid $exp" >> "$EXPIRED_FILE"
        fi

        sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
        sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
        rm -f /etc/xray/$user-tls.json /etc/xray/$user-none.json
    fi
done

#----- Auto Remove L2TP (TIDAK DIUBAH)
data=( `cat /var/lib/crot/data-user-l2tp | grep '^###' | cut -d ' ' -f 2`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
    exp=$(grep -w "^### $user" "/var/lib/crot/data-user-l2tp" | cut -d ' ' -f 3)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    if [[ "$exp2" = "0" ]]; then
        sed -i "/^### $user $exp/d" "/var/lib/crot/data-user-l2tp"
        sed -i '/^"'"$user"'" l2tpd/d' /etc/ppp/chap-secrets
        sed -i '/^'"$user"':\$1\$/d' /etc/ipsec.d/passwd
        chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd*
    fi
done

#----- Auto Remove PPTP (TIDAK DIUBAH)
data=( `cat /var/lib/crot/data-user-pptp | grep '^###' | cut -d ' ' -f 2`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
    exp=$(grep -w "^### $user" "/var/lib/crot/data-user-pptp" | cut -d ' ' -f 3)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    if [[ "$exp2" = "0" ]]; then
        sed -i "/^### $user $exp/d" "/var/lib/crot/data-user-pptp"
        sed -i '/^"'"$user"'" pptpd/d' /etc/ppp/chap-secrets
        chmod 600 /etc/ppp/chap-secrets*
    fi
done

#----- Auto Remove SSTP (TIDAK DIUBAH)
data=( `cat /var/lib/crot/data-user-sstp | grep '^###' | cut -d ' ' -f 2`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
    exp=$(grep -w "^### $user" "/var/lib/crot/data-user-sstp" | cut -d ' ' -f 3)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    if [[ "$exp2" = "0" ]]; then
        sed -i "/^### $user $exp/d" "/var/lib/crot/data-user-sstp"
        sed -i '/^'"$user"'/d' /home/sstp/sstp_account
    fi
done

#----- Auto Remove Vless
data=( `cat /etc/xray/config.json | grep '^#&' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
    exp=$(grep -w "^#& $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    if [[ "$exp2" -le "0" ]]; then
        # ambil block client vless
        block=$(sed -n "/^#& $user $exp/,/^},{/p" /etc/xray/config.json)
        uuid=$(echo "$block" | grep -m1 '"id"' | cut -d'"' -f4)

        if [ -n "$uuid" ]; then
            echo "$now vless $user $uuid $exp" >> "$EXPIRED_FILE"
        fi

        sed -i "/^#& $user $exp/,/^},{/d" /etc/xray/config.json
        sed -i "/^#& $user $exp/,/^},{/d" /etc/xray/config.json
    fi
done

#----- Auto Remove Trojan
data=( `cat /etc/xray/config.json | grep '^#!' | cut -d ' ' -f 2 | sort | uniq`);
now=`date +"%Y-%m-%d"`
for user in "${data[@]}"
do
    exp=$(grep -w "^#! $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    if [[ "$exp2" -le "0" ]]; then
        # ambil block client trojan
        block=$(sed -n "/^#! $user $exp/,/^},{/p" /etc/xray/config.json)

        # trojan biasanya pakai "password", tapi tetap cek "id" dulu
        uuid=$(echo "$block" | grep -m1 '"id"' | cut -d'"' -f4)
        if [ -z "$uuid" ]; then
            uuid=$(echo "$block" | grep -m1 '"password"' | cut -d'"' -f4)
        fi

        if [ -n "$uuid" ]; then
            echo "$now trojan $user $uuid $exp" >> "$EXPIRED_FILE"
        fi

        sed -i "/^#! $user $exp/,/^},{/d" /etc/xray/config.json
        sed -i "/^#! $user $exp/,/^},{/d" /etc/xray/config.json
    fi
done

systemctl restart xray

##------ Auto Remove SSH (TIDAK DIUBAH)
hariini=`date +%d-%m-%Y`
cat /etc/shadow | cut -d: -f1,8 | sed /:$/d > /tmp/expirelist.txt
totalaccounts=`cat /tmp/expirelist.txt | wc -l`
for((i=1; i<=$totalaccounts; i++ ))
do
    tuserval=`head -n $i /tmp/expirelist.txt | tail -n 1`
    username=`echo $tuserval | cut -f1 -d:`
    userexp=`echo $tuserval | cut -f2 -d:`
    userexpireinseconds=$(( $userexp * 86400 ))
    tglexp=`date -d @$userexpireinseconds`
    tgl=`echo $tglexp |awk -F" " '{print $3}'`
    while [ ${#tgl} -lt 2 ]
    do
        tgl="0"$tgl
    done
    while [ ${#username} -lt 15 ]
    do
        username=$username" "
    done
    bulantahun=`echo $tglexp |awk -F" " '{print $2,$6}'`
    todaystime=`date +%s`
    if [ $userexpireinseconds -ge $todaystime ] ;
    then
        :
    else
        userdel --force $username
    fi
done
