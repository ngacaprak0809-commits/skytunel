#!/bin/bash

echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;100;33m       • VLESS MENU •         \E[0m"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
echo -e " [\e[36m•1\e[0m] Create Account Vless "
echo -e " [\e[36m•2\e[0m] Trial Account Vless "
echo -e " [\e[36m•3\e[0m] Extending Account Vless "
echo -e " [\e[36m•4\e[0m] Delete Account Vless "
echo -e " [\e[36m•5\e[0m] Check User Login Vless "
echo -e " [\e[36m•6\e[0m] User list created Account "
echo -e ""
echo -e " [\e[31m•0\e[0m] \e[31mBACK TO MENU\033[0m"
echo -e ""
echo -e   "Press x or [ Ctrl+C ] • To-Exit"
echo ""
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -p " Select menu :  "  opt
echo -e ""
case $opt in
1) clear ; add-vless ; exit ;;
2) clear ; trialvless ; exit ;;
3) clear ; renew-vless ; exit ;;
4) clear ; del-vless ; exit ;;
5) clear ; cek-vless ; exit ;;
6) clear ;
   if [ -s /etc/log-create-vless.log ]; then
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
     ' /etc/log-create-vless.log | column -t
   else
     echo "Log VLESS kosong."
   fi
   echo ""
   read -n 1 -s -r -p "Press any key to back on menu"
   exit ;;
0) clear ; menu ; exit ;;
x) exit ;;
*) echo "Anda salah tekan " ; sleep 1 ; m-sshovpn ;;
esac
