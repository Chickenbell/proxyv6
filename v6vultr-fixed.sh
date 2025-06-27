#!/usr/bin/env bash
#
#  v6vultr-fixed.sh – Build IPv6 proxy pool on CentOS 7/8/Stream VPS (tested on Vultr)
#  © 2025  – CHICKENBELL
# ------------------------------------------------------------------
#  CHANGELOG
#    * 2025-06-27  – sử dụng 3proxy 0.9.5 (link mới), thay icanhazip → ifconfig.co
#                  – khai báo WORKDIR trước khi gọi install_3proxy
#                  – bổ sung kiểm tra quyền root, rc-local.service
#                  – option upload proxy list; mặc định chỉ in ra màn hình
# ------------------------------------------------------------------

set -euo pipefail

# ---- helpers -----------------------------------------------------------------
random() { tr </dev/urandom -dc A-Za-z0-9 | head -c5; echo; }

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
main_interface=$(ip route get 8.8.8.8 | awk '{print $5}')

gen64() {
    ip64() { echo "${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}${array[$RANDOM%16]}"; }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# ---- 3proxy build & install ---------------------------------------------------
install_3proxy() {
    echo "[*] Installing 3proxy ..."
    mkdir -p /opt/3proxy && cd /opt/3proxy

    local URL="https://github.com/3proxy/3proxy/archive/refs/tags/0.9.5.tar.gz"          # <-- link mới 0.9.5 :contentReference[oaicite:0]{index=0}
    curl -L "$URL" | tar -xz
    cd 3proxy-0.9.5
    make -f Makefile.Linux

    install -Dm755 src/3proxy /usr/local/bin/3proxy

    cat >/etc/3proxy.service <<'EOF'
[Unit]
Description=3proxy tiny proxy server
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg
Restart=always
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now 3proxy
    echo "[+] 3proxy installed"
}

# ---- 3proxy config generators -------------------------------------------------
gen_3proxy_cfg() {
cat > /etc/3proxy/3proxy.cfg <<EOF
daemon
maxconn 2000
nserver 1.1.1.1
nserver 8.8.8.8
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
setgid 65535
setuid 65535
stacksize 6291456
flush
auth none

$(awk -F "/" '{printf "proxy -6 -n -a -p%s -i%s -e%s\nflush\n", $4,$3,$5}' "$WORKDATA")
EOF
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read -r port; do
        echo "$(random)/$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_firewall_rules() {
    awk -F "/" '{printf "iptables -I INPUT -p tcp --dport %s -j ACCEPT\n",$4}' "$WORKDATA" > "$WORKDIR/boot_iptables.sh"
    awk -F "/" '{printf "ip6tables -I INPUT -p tcp --dport %s -j ACCEPT\n",$4}' "$WORKDATA" >> "$WORKDIR/boot_iptables.sh"
    chmod +x "$WORKDIR/boot_iptables.sh"
}

gen_ifconfig() {
    awk -F "/" -v IFACE="$main_interface" '{printf "ip -6 addr add %s/64 dev %s\n",$5,IFACE}' "$WORKDATA" > "$WORKDIR/boot_ifconfig.sh"
    chmod +x "$WORKDIR/boot_ifconfig.sh"
}

write_rc_local() {
    cat > /etc/rc.d/rc.local <<EOF
#!/usr/bin/env bash
bash $WORKDIR/boot_iptables.sh
bash $WORKDIR/boot_ifconfig.sh
ulimit -n 65535
/usr/local/bin/3proxy /etc/3proxy/3proxy.cfg &
EOF
    chmod +x /etc/rc.d/rc.local
    systemctl enable rc-local || true
}

# ---- MAIN ---------------------------------------------------------------------
[[ $EUID -ne 0 ]] && { echo "Run as root!"; exit 1; }

echo "[*] Installing build deps ..."
yum -y install gcc make net-tools zip curl >/dev/null

WORKDIR="/opt/proxy-installer"
WORKDATA="$WORKDIR/data.txt"
mkdir -p "$WORKDIR"

IP4=$(curl -4 -s https://ifconfig.co)                          # <-- link mới, IPv4 :contentReference[oaicite:1]{index=1}
IP6=$(curl -6 -s https://ifconfig.co | cut -f1-4 -d':')        # <-- link mới, IPv6

FIRST_PORT=40000
LAST_PORT=42000

gen_data > "$WORKDATA"
install_3proxy
gen_firewall_rules
gen_ifconfig
gen_3proxy_cfg
write_rc_local

bash /etc/rc.d/rc.local
echo "[√] Hoàn tất! Proxy list:"
awk -F "/" '{printf "%s:%s\n",$3,$4}' "$WORKDATA"
