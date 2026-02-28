#!/bin/bash
# cari apa..?? harta tahta hanya sementara ingat masih ada kehidupan setelah kematian
# jangan lupa sholat ingat ajal menantimu
# dibawah ini bukan cd kaset ya
cd
rm -rf setup.sh
clear
red='\e[1;31m'
green='\e[0;32m'
yell='\e[1;33m'
tyblue='\e[1;36m'
BRed='\e[1;31m'
BGreen='\e[1;32m'
BYellow='\e[1;33m'
BBlue='\e[1;34m'
NC='\e[0m'
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
cd /root
#System version number
if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
  sleep 5
		exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo "OpenVZ is not supported"
  clear
                echo "For VPS with KVM and VMWare virtualization ONLY"
  sleep 5
		exit 1
fi

localip=$(hostname -I | cut -d\  -f1)
hst=( `hostname` )
dart=$(cat /etc/hosts | grep -w `hostname` | awk '{print $2}')
if [[ "$hst" != "$dart" ]]; then
echo "$localip $(hostname)" >> /etc/hosts
fi
# buat folder
mkdir -p /etc/xray
mkdir -p /etc/v2ray
touch /etc/xray/domain
touch /etc/v2ray/domain
touch /etc/xray/scdomain
touch /etc/v2ray/scdomain


echo -e "[ ${BBlue}NOTES${NC} ] Before we go.. "
sleep 0.5
echo -e "[ ${BBlue}NOTES${NC} ] I need check your headers first.."
sleep 0.5
echo -e "[ ${BGreen}INFO${NC} ] Checking headers"
sleep 0.5
totet=`uname -r`
REQUIRED_PKG="linux-headers-$totet"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
echo Checking for $REQUIRED_PKG: $PKG_OK
if [ "" = "$PKG_OK" ]; then
  sleep 0.5
  echo -e "[ ${BRed}WARNING${NC} ] Try to install ...."
  echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
  apt-get --yes install $REQUIRED_PKG
  sleep 0.5
  echo ""
  sleep 0.5
  echo -e "[ ${BBlue}NOTES${NC} ] If error you need.. to do this"
  sleep 0.5
  echo ""
  sleep 0.5
  echo -e "[ ${BBlue}NOTES${NC} ] apt update && apt upgrade -y && reboot"
  sleep 0.5
  echo ""
  sleep 0.5
  echo -e "[ ${BBlue}NOTES${NC} ] After this"
  sleep 0.5
  echo -e "[ ${BBlue}NOTES${NC} ] Then run this script again"
  echo -e "[ ${BBlue}NOTES${NC} ] enter now"
  read
else
  echo -e "[ ${BGreen}INFO${NC} ] Oke installed"
fi

ttet=`uname -r`
ReqPKG="linux-headers-$ttet"
if ! dpkg -s $ReqPKG  >/dev/null 2>&1; then
  rm /root/setup.sh >/dev/null 2>&1 
  exit
else
  clear
fi


secs_to_human() {
    echo "Installation time : $(( ${1} / 3600 )) hours $(( (${1} / 60) % 60 )) minute's $(( ${1} % 60 )) seconds"
}
start=$(date +%s)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime1

echo -e "[ ${BGreen}INFO${NC} ] Preparing the install file"
apt install git curl -y >/dev/null 2>&1
apt install python -y >/dev/null 2>&1
echo -e "[ ${BGreen}INFO${NC} ] Aight good ... installation file is ready"
sleep 0.5
echo -ne "[ ${BGreen}INFO${NC} ] Check permission : "

echo -e "$BGreen Permission Accepted!$NC"
sleep 2

mkdir -p /var/lib/ >/dev/null 2>&1
echo "IP=" >> /var/lib/ipvps.conf

echo ""
clear
echo -e "$BBlue                     SETUP DOMAIN VPS     $NC"
echo -e "$BYellow----------------------------------------------------------$NC"
echo -e "$BGreen 1. Use Domain Random / Gunakan Domain Random $NC"
echo -e "$BGreen 2. Choose Your Own Domain / Gunakan Domain Sendiri $NC"
echo -e "$BYellow----------------------------------------------------------$NC"
read -rp " input 1 or 2 / pilih 1 atau 2 : " dns
if test $dns -eq 1; then
curl -sL https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/ssh/cf.sh | bash
elif test $dns -eq 2; then
read -rp "Enter Your Domain / masukan domain : " dom
echo "IP=$dom" > /var/lib/ipvps.conf
echo "$dom" > /root/scdomain
echo "$dom" > /etc/xray/scdomain
echo "$dom" > /etc/xray/domain
echo "$dom" > /etc/v2ray/domain
echo "$dom" > /root/domain
else 
echo "Not Found Argument"
exit 1
fi
echo -e "${BGreen}Done!${NC}"
sleep 2
clear

#install golang
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen      Install golang          $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
curl -s https://go.dev/VERSION?m=text | head -n 1 | \
    xargs -I {} wget https://go.dev/dl/{}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go*.linux-amd64.tar.gz && \
    rm go*.linux-amd64.tar.gz
#install ssh ovpn
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen      Install SSH Websocket           $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/ssh/ssh-vpn.sh && chmod +x ssh-vpn.sh && ./ssh-vpn.sh
#Instal Update Script
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen      Install Update Script           $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
wget -O /usr/bin/m-update https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/update/update.sh && chmod +x /usr/bin/m-update
#Instal Xray
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen          Install XRAY              $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/xray/ins-xray.sh && chmod +x ins-xray.sh && ./ins-xray.sh
wget https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/sshws/insshws.sh && chmod +x insshws.sh && ./insshws.sh
#Instal IPSec
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen          Install IPSec              $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/ipsec/ipsec.sh && chmod +x ipsec.sh && ./ipsec.sh
wget https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/sstp/sstp.sh && chmod +x sstp.sh && ./sstp.sh
clear
#Instal ws
echo -e "\e[33m-----------------------------------\033[0m"
echo -e "$BGreen          Install websocket              $NC"
echo -e "\e[33m-----------------------------------\033[0m"
sleep 0.5
clear
wget https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/websocket/websocket.sh && chmod +x websocket.sh && ./websocket.sh
clear
#!/bin/bash

echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;100;33m      • TROJAN MENU •          \E[0m"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
echo -e " [\e[36m•1\e[0m] Create Account Trojan "
echo -e " [\e[36m•2\e[0m] Trial Account Trojan "
echo -e " [\e[36m•3\e[0m] Extending Account Trojan "
echo -e " [\e[36m•4\e[0m] Delete Account Trojan "
echo -e " [\e[36m•5\e[0m] Check User Login Trojan "
echo -e " [\e[36m•6\e[0m] User list created Account "
echo -e ""
echo -e " [\e[31m•0\e[0m] \e[31mBACK TO MENU\033[0m"
echo -e   ""
echo -e   "Press x or [ Ctrl+C ] • To-Exit"
echo ""
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -p " Select menu : " opt
echo -e ""
case $opt in
1) clear ; add-tr ;;
2) clear ; trialtrojan ;;
3) clear ; renew-tr ;;
4) clear ; del-tr ;;
5) clear ; cek-tr ;;
6) clear ;
   if [ -s /etc/log-create-trojan.log ]; then
     awk '
       /Remarks[[:space:]]*:/ {
         gsub(/\033\[[0-9;]*[A-Za-z]/,"",$0);
         gsub(/.*:[[:space:]]*/,"",$0);
         remark=$0;
       }
       /Expired On[[:space:]]*:/ {
         gsub(/\033\[[0-9;]*[A-Za-z]/,"",$0);
         gsub(/.*:[[:space:]]*/,"",$0);
         if(remark!=""){
           printf "%-25s %s\n", remark, $0;
           remark="";
         }
       }
     ' /etc/log-create-trojan.log | column -t
   else
     echo "Log Trojan kosong."
   fi
   echo ""
   read -n 1 -s -r -p "Press any key to back on menu"
   exit ;;
0) clear ; menu ;;
x) exit ;;
*) echo "Anda Salah Tekan" ; sleep 1 ; m-trojan ;;
esac
clear
# Install backup/restore tools and updated system menu
wget -O /usr/bin/backup.sh https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/menu/backup.sh
wget -O /usr/bin/restore.sh https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/menu/restore.sh
wget -O /usr/bin/m-system https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/menu/m-system.sh
apt install rclone python3-pip -y >/dev/null 2>&1
chmod +x /usr/bin/backup.sh /usr/bin/restore.sh /usr/bin/m-system
cat> /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
END
chmod 644 /root/.profile

if [ -f "/root/log-install.txt" ]; then
rm /root/log-install.txt > /dev/null 2>&1
fi
if [ -f "/etc/afak.conf" ]; then
rm /etc/afak.conf > /dev/null 2>&1
fi
if [ ! -f "/etc/log-create-ssh.log" ]; then
echo "Log SSH Account " > /etc/log-create-ssh.log
fi
if [ ! -f "/etc/log-create-vmess.log" ]; then
echo "Log Vmess Account " > /etc/log-create-vmess.log
fi
if [ ! -f "/etc/log-create-vless.log" ]; then
echo "Log Vless Account " > /etc/log-create-vless.log
fi
if [ ! -f "/etc/log-create-trojan.log" ]; then
echo "Log Trojan Account " > /etc/log-create-trojan.log
fi
if [ ! -f "/etc/log-create-shadowsocks.log" ]; then
echo "Log Shadowsocks Account " > /etc/log-create-shadowsocks.log
fi

serverV=$( curl -sS https://raw.githubusercontent.com/ngacaprak0809-commits/skytunel/refs/heads/main/menu/versi  )
echo $serverV > /opt/.ver
aureb=$(cat /home/re_otm)
b=11
if [ $aureb -gt $b ]
then
gg="PM"
else
gg="AM"
fi
curl -sS http://checkip.amazonaws.com/ > /etc/myipvps
echo ""
echo "=================================================================="  | tee -a log-install.txt
echo "      ___                                    ___         ___      "  | tee -a log-install.txt
echo "     /  /\        ___           ___         /  /\       /__/\     "  | tee -a log-install.txt
echo "    /  /:/_      /  /\         /__/\       /  /::\      \  \:\    "  | tee -a log-install.txt
echo "   /  /:/ /\    /  /:/         \  \:\     /  /:/\:\      \  \:\   "  | tee -a log-install.txt
echo "  /  /:/_/::\  /__/::\          \  \:\   /  /:/~/:/  _____\__\:\  "  | tee -a log-install.txt
echo " /__/:/__\/\:\ \__\/\:\__   ___  \__\:\ /__/:/ /:/  /__/::::::::\ "  | tee -a log-install.txt
echo " \  \:\ /~~/:/    \  \:\/\ /__/\ |  |:| \  \:\/:/   \  \:\~~\~~\/ "  | tee -a log-install.txt
echo "  \  \:\  /:/      \__\::/ \  \:\|  |:|  \  \::/     \  \:\  ~~~  "  | tee -a log-install.txt
echo "   \  \:\/:/       /__/:/   \  \:\__|:|   \  \:\      \  \:\      "  | tee -a log-install.txt
echo "    \  \::/        \__\/     \__\::::/     \  \:\      \  \:\     "  | tee -a log-install.txt
echo "     \__\/                       ~~~~       \__\/       \__\/ 1.0 "  | tee -a log-install.txt
echo "=================================================================="  | tee -a log-install.txt
echo ""
echo "   >>> Service & Port"  | tee -a log-install.txt
echo "   - OpenSSH                  : 22"  | tee -a log-install.txt
echo "   - SSH Websocket            : 80" | tee -a log-install.txt
echo "   - SSH SSL Websocket        : 443" | tee -a log-install.txt
echo "   - Stunnel4                 : 222, 777" | tee -a log-install.txt
echo "   - Badvpn                   : 7100-7900" | tee -a log-install.txt
echo "   - Nginx                    : 81" | tee -a log-install.txt
echo "   - Vmess WS TLS             : 443" | tee -a log-install.txt
echo "   - Vless WS TLS             : 443" | tee -a log-install.txt
echo "   - Trojan WS TLS            : 443" | tee -a log-install.txt
echo "   - Shadowsocks WS TLS       : 443" | tee -a log-install.txt
echo "   - Vmess WS none TLS        : 80" | tee -a log-install.txt
echo "   - Vless WS none TLS        : 80" | tee -a log-install.txt
echo "   - Trojan WS none TLS       : 80" | tee -a log-install.txt
echo "   - Shadowsocks WS none TLS  : 80" | tee -a log-install.txt
echo "   - Vmess gRPC               : 443" | tee -a log-install.txt
echo "   - Vless gRPC               : 443" | tee -a log-install.txt
echo "   - Trojan gRPC              : 443" | tee -a log-install.txt
echo "   - Shadowsocks gRPC         : 443" | tee -a log-install.txt
echo ""
echo "=============================Contact==============================" | tee -a log-install.txt
echo "--------------------------t.me/caliphdev--------------------------" | tee -a log-install.txt
echo "==================================================================" | tee -a log-install.txt
echo -e ""
echo ""
echo "" | tee -a log-install.txt
rm /root/setup.sh >/dev/null 2>&1
rm /root/ins-xray.sh >/dev/null 2>&1
rm /root/insshws.sh >/dev/null 2>&1
secs_to_human "$(($(date +%s) - ${start}))" | tee -a log-install.txt
echo -e ""
for i in {10..1}; do echo -ne "\rAuto reboot in $i Seconds "; sleep 1; done
echo -e "Rebooting...";
rm -rf setup.sh
reboot
