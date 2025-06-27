#!/bin/bash
#================================================================
#  IPv6 Proxy Installer for Vultr VPS – 3proxy 0.9.3
#  Written 27-Jun-2025 – ChatGPT
#================================================================
set -euo pipefail

### ---------- CÀI ĐẶT NHANH ------------------------------------
WORKDIR="/home/proxy-installer"
FIRST_PORT=40000              # cổng đầu
LAST_PORT=42000               # cổng cuối
PROXY_VER="0.9.3"
PROXY_URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/${PROXY_VER}.tar.gz"
AUTH_MODE="${AUTH_MODE:-none}"    # none | strong
PACKAGE_LIST=(gcc make tar wget curl zip iproute net-tools)
#----------------------------------------------------------------

main_iface() { ip route get 8.8.8.8 | awk '{print $5;exit}'; }
random_str() { tr </dev/urandom -dc A-Za-z0-9 | head -c5; }

gen_ipv6() {                      # sinh 1 IPv6 /64 ngẫu nhiên, đúng chuẩn
  local prefix=$1
  printf "%s:%04x:%04x:%04x:%04x\n" \
    "$prefix" \
    $((RANDOM%65536)) $((RANDOM%65536)) \
    $((RANDOM%65536)) $((RANDOM%65536))
}

install_pkgs() {
  echo ">> Installing packages"
  if command -v dnf &>/dev/null; then
    dnf install -y "${PACKAGE_LIST[@]}"
  else
    yum install -y "${PACKAGE_LIST[@]}"
  fi
}

install_3proxy() {
  echo ">> Installing 3proxy $PROXY_VER"
  mkdir -p /3proxy && cd /3proxy
  curl -sSL "$PROXY_URL" | tar -xz
  cd "3proxy-$PROXY_VER"
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
}

enable_sysctl() {
  local nic
  nic=$(main_iface)
  cat >>/etc/sysctl.conf <<EOF
net.ipv6.conf.${nic}.proxy_ndp = 1
net.ipv6.conf.all.proxy_ndp    = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding     = 1
net.ipv6.ip_nonlocal_bind        = 1
EOF
  sysctl -p
}

generate_data() {
  local ip4 ip6prefix
  ip4=$(curl -4 -s icanhazip.com)
  ip6prefix=$(curl -6 -s icanhazip.com | cut -d':' -f1-4)

  mkdir -p "$WORKDIR"
  local port user pass ipv6
  : >"$WORKDIR/data.txt"

  for port in $(seq $FIRST_PORT $LAST_PORT); do
    ipv6=$(gen_ipv6 "$ip6prefix")
    if [[ $AUTH_MODE == strong ]]; then
      user=$(random_str); pass=$(random_str)
      echo "$user/$pass/$ip4/$port/$ipv6" >>"$WORKDIR/data.txt"
    else
      echo "none/none/$ip4/$port/$ipv6"   >>"$WORKDIR/data.txt"
    fi
  done
}

assign_ipv6() {
  echo ">> Assigning IPv6"
  local nic
  nic=$(main_iface)
  awk -F/ -v nic="$nic" '{print "ip -6 addr add "$5"/64 dev "nic}' "$WORKDIR/data.txt" \
    >"$WORKDIR/boot_ifconfig.sh"
  chmod +x "$WORKDIR/boot_ifconfig.sh"
  bash "$WORKDIR/boot_ifconfig.sh"
}

open_ports() {
  echo ">> Opening ports"
  awk -F/ '{print "iptables -I INPUT -p tcp --dport "$4" -j ACCEPT"}' \
    "$WORKDIR/data.txt" >"$WORKDIR/boot_iptables.sh"
  chmod +x "$WORKDIR/boot_iptables.sh"
  bash "$WORKDIR/boot_iptables.sh"
}

build_3proxy_cfg() {
  echo ">> Creating 3proxy.cfg"
  {
    echo "daemon";
    echo "maxconn 2000";
    echo "nserver 1.1.1.1";
    echo "nserver 2001:4860:4860::8888";
    echo "nscache 65536";
    if [[ $AUTH_MODE == strong ]]; then
      echo -n "users "
      awk -F/ '{printf $1":CL:"$2" "}' "$WORKDIR/data.txt"; echo
      echo "auth strong"
    else
      echo "auth none"
    fi
    echo
    awk -F/ '{print "proxy -6 -n -a -p"$4" -i"$3" -e"$5"\nflush"}' "$WORKDIR/data.txt"
  } >/usr/local/etc/3proxy/3proxy.cfg
}

make_startup() {
  echo ">> Configuring rc.local"
  cat >/etc/rc.local <<EOF
#!/bin/bash
bash $WORKDIR/boot_ifconfig.sh
bash $WORKDIR/boot_iptables.sh
ulimit -n 65535
systemctl start 3proxy
EOF
  chmod +x /etc/rc.local
}

export_proxy_list() {
  local list out zipname link
  if [[ $AUTH_MODE == strong ]]; then
    list="proxy_auth.txt"
    awk -F/ '{print $3":"$4":"$1":"$2}' "$WORKDIR/data.txt" >"$WORKDIR/$list"
  else
    list="proxy.txt"
    awk -F/ '{print $3":"$4}' "$WORKDIR/data.txt" >"$WORKDIR/$list"
  fi
  zipname="$(hostname -I | awk '{print $1}').zip"
  cd "$WORKDIR" && zip -q "$zipname" "$list"
  link=$(curl -sF "file=@$zipname" https://file.io | cut -d'"' -f8)
  echo -e "\n===== LINK TẢI $list =====\n$link\n===========================\n"
}

disable_firewalld() {
  systemctl stop firewalld 2>/dev/null || true
  systemctl disable firewalld 2>/dev/null || true
}

main() {
  install_pkgs
  install_3proxy
  enable_sysctl
  generate_data
  assign_ipv6
  open_ports
  build_3proxy_cfg
  make_startup
  disable_firewalld
  echo ">> Starting 3proxy"
  systemctl restart 3proxy
  systemctl status 3proxy --no-pager
  export_proxy_list
  echo "=== FINISHED: Your IPv6 proxies are ready! ==="
}

main
