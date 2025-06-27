#!/bin/bash
#=============================================================
#  IPv6 proxy installer for CentOS/Alma/RHEL 8 (Vultr VPS)
#  Fixed 27-Jun-2025 – by ChatGPT
#=============================================================

set -euo pipefail

### ----------- TÙY CHỈNH NHANH ---------------------------------
WORKDIR="/home/proxy-installer"
WORKDATA="${WORKDIR}/data.txt"
FIRST_PORT=40000            # cổng đầu
LAST_PORT=42000             # cổng cuối
PROXY_VERSION="0.9.3"
PROXY_URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/${PROXY_VERSION}.tar.gz"
PACKAGE_LIST=(gcc make tar wget curl zip net-tools)
#----------------------------------------------------------------

random() { tr </dev/urandom -dc A-Za-z0-9 | head -c5; echo; }

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)          # phục vụ sinh IPv6
main_interface=$(ip route get 8.8.8.8 | awk '{print $5; exit}')

gen64() {                                         # sinh 1 IP /64 ngẫu nhiên
  ip64() { echo "${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}"; }
  echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_packages() {
  echo ">> Cài gói bắt buộc"
  if command -v dnf &>/dev/null; then
      dnf  install -y "${PACKAGE_LIST[@]}"
  else
      yum  install -y "${PACKAGE_LIST[@]}"
  fi
}

install_3proxy() {
  echo ">> Cài 3proxy ${PROXY_VERSION}"
  mkdir -p /3proxy && cd /3proxy
  curl -sSL "${PROXY_URL}" | tar -xz
  cd "3proxy-${PROXY_VERSION}"
  make -f Makefile.Linux
  install -m755 bin/3proxy /usr/local/bin/3proxy
  mkdir -p /usr/local/etc/3proxy/{logs,stat}

  cat >/usr/lib/systemd/system/3proxy.service <<'EOF'
[Unit]
Description=3proxy tiny proxy server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable 3proxy

  echo ">> Bật forward & NDP proxy"
  cat >>/etc/sysctl.conf <<EOF
net.ipv6.conf.${main_interface}.proxy_ndp = 1
net.ipv6.conf.all.proxy_ndp       = 1
net.ipv6.conf.default.forwarding  = 1
net.ipv6.conf.all.forwarding      = 1
net.ipv6.ip_nonlocal_bind         = 1
EOF
  sysctl -p

  echo ">> Tắt firewalld để mở port"
  systemctl stop firewalld  2>/dev/null || true
  systemctl disable firewalld 2>/dev/null || true
}

gen_data() {                 # user/pass/IP/port/IPv6
  seq $FIRST_PORT $LAST_PORT | while read -r port; do
    echo "$(random)/$(random)/${IP4}/${port}/$(gen64 ${IP6})"
  done
}

gen_iptables()  { awk -F/ '{print "iptables -I INPUT -p tcp --dport "$4" -m state --state NEW -j ACCEPT"}'  "$WORKDATA"; }
gen_ifconfig()  { awk -F/ -v nic="$main_interface" '{print "ifconfig "nic" inet6 add "$5"/64"}' "$WORKDATA"; }

gen_3proxy_cfg() {
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

users $(awk -F/ 'BEGIN{ORS="";}{printf $1":CL:"$2" "}' "$WORKDATA")

$(awk -F/ '{print "auth none\nallow "$1"\nproxy -6 -n -a -p"$4" -i"$3" -e"$5"\nflush\n"}' "$WORKDATA")
EOF
}

gen_proxy_file_for_user() { awk -F/ '{print $3":"$4":"$1":"$2}' "$WORKDATA" >"$WORKDIR/proxy.txt"; }

upload_proxy() {
  cd "$WORKDIR"
  zip -q "${IP4}.zip" proxy.txt
  URL=$(curl -F "file=@${IP4}.zip" https://file.io)
  echo -e "\n==============  LINK TẢI DANH SÁCH PROXY  =============="
  echo "$URL"
  echo "========================================================\n"
}

prepare_boot_scripts() {
  echo ">> Tạo script iptables & ifconfig"
  gen_iptables >"$WORKDIR/boot_iptables.sh"
  gen_ifconfig >"$WORKDIR/boot_ifconfig.sh"
  chmod +x "$WORKDIR"/boot_*.sh
}

setup_rc_local() {
  echo ">> Khởi tạo /etc/rc.local để chạy lại sau reboot"
  cat >/etc/rc.local <<EOF
#!/bin/bash
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 65535
systemctl start 3proxy
EOF
  chmod +x /etc/rc.local
}

main() {
  install_packages
  install_3proxy

  mkdir -p "$WORKDIR"
  IP4=$(curl -4 -s icanhazip.com)
  IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
  echo "IPv4  = $IP4"
  echo "IPv6/64 prefix = $IP6"

  gen_data  >"$WORKDATA"
  gen_3proxy_cfg >/usr/local/etc/3proxy/3proxy.cfg

  prepare_boot_scripts
  setup_rc_local

  echo ">> Khởi động 3proxy"
  systemctl start 3proxy
  systemctl status 3proxy --no-pager

  gen_proxy_file_for_user
  upload_proxy

  echo "HOÀN TẤT – Thưởng thức proxy IPv6 của bạn!"
}

main
