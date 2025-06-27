#!/bin/sh
random() {
	tr </dev/urandom -dc A-Za-z0-9 | head -c5
	echo
}

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
main_interface=$(ip route get 8.8.8.8 | awk -- '{printf $5}')
gen64() {
	ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
	echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}
install_3proxy() {
  echo "installing 3proxy"
  mkdir -p /3proxy && cd /3proxy

  # 1. Tải mã nguồn
  URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.3.tar.gz"
  wget -qO- "$URL" | tar -xz
  cd 3proxy-0.9.3

  # 2. Biên dịch
  make -f Makefile.Linux

  # 3. Cài đặt
  mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
  install -m 755 src/3proxy /usr/local/etc/3proxy/bin/3proxy

  # 4. Service systemd
  cat >/usr/lib/systemd/system/3proxy.service <<'EOF'
[Unit]
Description=3proxy tiny proxy server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
Restart=always
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable 3proxy

  # 5. Kernel & firewall tối ưu
  echo "net.ipv6.conf.$main_interface.proxy_ndp=1" >> /etc/sysctl.conf
  echo "net.ipv6.conf.all.proxy_ndp=1" >> /etc/sysctl.conf
  echo "net.ipv6.conf.default.forwarding=1" >> /etc/sysctl.conf
  echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
  echo "net.ipv6.ip_nonlocal_bind = 1" >> /etc/sysctl.conf
  sysctl -p
  systemctl stop firewalld --quiet 2>/dev/null || true
  systemctl disable firewalld --quiet 2>/dev/null || true

  cd "$WORKDIR"
}

gen_3proxy() {
    cat <<EOF
daemon
maxconn 2000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456
flush
auth none

users $(awk -F "/" 'BEGIN{ORS="";} {print $1 ":CL:" $2 " "}' ${WORKDATA})

$(awk -F "/" '{print "auth none\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    cat >proxy.txt <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}

upload_proxy() {
    cd $WORKDIR
    local PASS=$(random)
    zip ${IP4}.zip proxy.txt
    URL=$(curl -F "file=@${IP4}.zip" https://file.io)
    echo "Download zip archive from: ${URL}"


}
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$(random)/$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA})
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig '$main_interface' inet6 add " $5 "/64"}' ${WORKDATA})
EOF
}
echo "installing apps"
yum -y install gcc net-tools bsdtar zip make >/dev/null

install_3proxy

echo "working folder = /home/proxy-installer"
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir $WORKDIR && cd $_

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"

FIRST_PORT=40000
LAST_PORT=42000

gen_data >$WORKDIR/data.txt
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
echo NM_CONTROLLED="no" >> /etc/sysconfig/network-scripts/ifcfg-${main_interface}
chmod +x $WORKDIR/boot_*.sh /etc/rc.local

gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

cat >>/etc/rc.local <<EOF
#systemctl start NetworkManager.service
# ifup ${main_interface}
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 65535
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg &
EOF

bash /etc/rc.local

gen_proxy_file_for_user

upload_proxy
