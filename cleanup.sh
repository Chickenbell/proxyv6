#!/bin/bash
# cleanup_and_regenerate.sh
systemctl stop 3proxy
pkill -f 3proxy
iptables -F
ip -6 addr flush dev $(ip route get 8.8.8.8 | awk '{print $5}')
rm -f /usr/local/etc/3proxy/3proxy.cfg /home/chickenbell/data.txt /home/chickenbell/proxy.txt
systemctl restart network
sleep 5
