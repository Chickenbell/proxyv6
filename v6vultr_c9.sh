#!/bin/bash
#================================================================
# v6vultr_c9.sh  –  IPv6 mass-proxy installer for CentOS 9
# Author : ChatGPT (27-Jun-2025)
#================================================================
set -euo pipefail

###====================== Cấu hình nhanh ========================
WORKDIR="/home/proxy-installer"
FIRST_PORT=40000                            # cổng đầu tiên
DEFAULT_COUNT=2000                          # số proxy mặc định
PROXY_VER="0.9.3"
PROXY_URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/${PROXY_VER}.tar.gz"
PKGS=(gcc make tar wget curl zip iproute net-tools)

#== Nhận tham số CLI =====
COUNT="${1:-$DEFAULT_COUNT}"                # ./script.sh 5000
AUTH_MODE="${2:-none}"                      # ./script.sh 5000 strong
[[ "$AUTH_MODE" != "none" && "$AUTH_MODE" != "strong" ]] && AUTH_MODE=none
[[ "$COUNT" =~ ^[0-9]+$ ]] || { echo "COUNT phải là số"; exit 1; }
LAST_PORT=$(( FIRST_PORT + COUNT - 1 ))
###==============================================================

main_iface() { ip route get 8.8.8.8 | awk '{print $5;exit}'; }
rand_hex()    { printf '%04x' $(( RANDOM % 65536 )); }
rand_str()    { tr </dev/urandom -dc A-Za-z0-9 | head -c8; }

install_pkgs() {
  dnf install -y epel-release &>/dev/null || true
  dnf install -y "${PKGS[@]}"
}

install_3proxy() {
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
Restart=always
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable 3proxy
}

tune_kernel() {
  local nic=$(main_iface)
  cat >>/etc/sysctl.conf <<EOF
net.ipv6.conf.${nic}.proxy_ndp = 1
net.ipv6.conf.all.proxy_ndp    = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding     = 1
net.ipv6.ip_nonlocal_bind        = 1
EOF
  sysctl -p
}

generate_files() {
  mkdir -p "$WORKDIR"
  local ip4 ip6pref port ipv6 user pass
  ip4=$(curl -4 -s icanhazip.com)
  ip6pref=$(curl -6 -s icanhazip.com | cut -d':' -f1-4)

  : >"$WORKDIR/data.txt"
  for ((port=FIRST_PORT; port<=LAST_PORT; port++)); do
    ipv6="${ip6pref}:$(rand_hex):$(rand_hex):$(rand_hex):$(rand_hex)"
    if [[ $AUTH_MODE == strong ]]; then
      user=$(rand_str); pass=$(rand_str)
      echo "$user/$pass/$ip4/$port/$ipv6" >>"$WORKDIR/data.txt"
    else
      echo "none/none/$ip4/$port/$ipv6"    >>"$WORKDIR/data.txt"
    fi
  done

  # proxy.txt
  if [[ $AUTH_MODE == strong ]]; then
    awk -F/ '{print $3":"$4":"$1":"$2}' "$WORKDIR/data.txt" >"$WORKDIR/proxy.txt"
  else
    awk -F/ '{print $3":"$4}'             "$WORKDIR/data.txt" >"$WORKDIR/proxy.txt"
  fi
}

assign_ipv6() {
  local nic=$(main_iface)
  awk -F/ -v nic="$nic" '{print "ip -6 addr add "$5"/64 dev "nic}' \
      "$WORKDIR/data.txt" | bash
}

open_firewall() {
  # firewalld có thể chạy, tắt cho đơn giản
  systemctl stop firewalld 2>/dev/null || true
  systemctl disable firewalld 2>/dev/null || true
  # iptables rule
  iptables -I INPUT -p tcp --dport ${FIRST_PORT}:${LAST_PORT} -j ACCEPT
}

build_3proxy_cfg() {
  {
    echo "daemon"
    echo "maxconn 2000"
    echo "nserver 1.1.1.1"
    echo "nserver 2001:4860:4860::8888"
    echo "nscache 65536"
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

bootstrap_rc() {
  cat >/etc/rc.local <<EOF
#!/bin/bash
$(awk -F/ '{print "ip -6 addr add "$5"/64 dev '$(main_iface)';"}' "$WORKDIR/data.txt")
iptables -I INPUT -p tcp --dport ${FIRST_PORT}:${LAST_PORT} -j ACCEPT 2>/dev/null || true
ulimit -n 65535
systemctl start 3proxy
EOF
  chmod +x /etc/rc.local
}

start_proxy() {
  systemctl restart 3proxy
  systemctl status 3proxy --no-pager
}

upload_proxy() {
  cd "$WORKDIR"
  zip -q proxy.zip proxy.txt data.txt
  echo -e "\nĐang upload danh sách proxy..."
  local link=$(curl -sF "file=@proxy.zip" https://file.io | grep -o '"https:[^"]*')
  echo -e "\n🔗  LINK TẢI: $link\n"
}

###======================= MAIN FLOW ============================
echo -e ">> Cài đặt $COUNT proxy IPv6  (AUTH=$AUTH_MODE)\n"
install_pkgs
install_3proxy
tune_kernel
generate_files
assign_ipv6
open_firewall
build_3proxy_cfg
bootstrap_rc
start_proxy
upload_proxy
echo "✅ Hoàn tất! Proxy đã sẵn sàng."
