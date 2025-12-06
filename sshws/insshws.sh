#!/bin/bash
clear
cd

#Install Script Websocket-SSH golang
wget -O /usr/local/bin/ws-stunnel.go https://autoscript.caliphdev.com/sshws/ws-stunnel.go
go build -o /usr/local/bin/ws-stunnel /usr/local/bin/ws-stunnel.go
chmod +x /usr/local/bin/ws-stunnel


#izin permision
chmod +x /usr/local/bin/ws-dropbear

#System SSL/TLS Websocket-SSH Python
wget -O /etc/systemd/system/ws-stunnel.service https://autoscript.caliphdev.com/sshws/ws-stunnel.service && chmod +x /etc/systemd/system/ws-stunnel.service


#restart service
systemctl daemon-reload

#Enable & Start & Restart ws-dropbear service
systemctl enable ws-dropbear.service
systemctl start ws-dropbear.service
systemctl restart ws-dropbear.service

#Enable & Start & Restart ws-openssh service
systemctl enable ws-stunnel.service
systemctl start ws-stunnel.service
systemctl restart ws-stunnel.service
