#!/bin/bash

# Script tạo proxy IPv6 cho CentOS 9
# Tác giả: Auto Generated Script

# Màu sắc cho output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Hàm hiển thị banner
show_banner() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "     IPv6 Proxy Generator for CentOS 9"
    echo "=================================================="
    echo -e "${NC}"
}

# Hàm log
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Kiểm tra quyền root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Script này cần chạy với quyền root!"
        exit 1
    fi
}

# Cài đặt các package cần thiết
install_requirements() {
    log "Cài đặt các package cần thiết..."
    
    # Update system
    dnf update -y >/dev/null 2>&1
    
    # Install required packages
    dnf install -y epel-release >/dev/null 2>&1
    dnf install -y 3proxy curl wget jq >/dev/null 2>&1
    
    if ! command -v 3proxy &> /dev/null; then
        error "Không thể cài đặt 3proxy. Vui lòng cài đặt thủ công."
        exit 1
    fi
    
    log "Cài đặt hoàn tất!"
}

# Lấy thông tin IPv6
get_ipv6_info() {
    log "Lấy thông tin IPv6..."
    
    # Lấy IPv6 address chính
    MAIN_IPV6=$(ip -6 addr show | grep 'inet6.*global' | head -1 | awk '{print $2}' | cut -d'/' -f1)
    
    if [[ -z "$MAIN_IPV6" ]]; then
        error "Không tìm thấy IPv6 address!"
        exit 1
    fi
    
    # Lấy network prefix
    IPV6_PREFIX=$(echo $MAIN_IPV6 | cut -d':' -f1-4)
    
    log "IPv6 chính: $MAIN_IPV6"
    log "Prefix: $IPV6_PREFIX"
}

# Tạo danh sách IPv6
generate_ipv6_list() {
    local count=$1
    log "Tạo $count địa chỉ IPv6..."
    
    > ipv6_list.tmp
    
    for ((i=1; i<=count; i++)); do
        # Tạo random suffix cho IPv6
        suffix=$(printf "%x" $((RANDOM * RANDOM)))
        ipv6="${IPV6_PREFIX}::${suffix}"
        echo "$ipv6" >> ipv6_list.tmp
    done
    
    log "Đã tạo $count địa chỉ IPv6"
}

# Cấu hình IPv6 addresses
configure_ipv6_addresses() {
    local count=$1
    log "Cấu hình $count IPv6 addresses..."
    
    # Lấy interface chính
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    
    # Thêm IPv6 addresses
    local counter=1
    while read -r ipv6; do
        ip -6 addr add ${ipv6}/128 dev $INTERFACE 2>/dev/null
        ((counter++))
        
        if ((counter % 100 == 0)); then
            log "Đã cấu hình $counter/$count addresses..."
        fi
    done < ipv6_list.tmp
    
    log "Cấu hình IPv6 addresses hoàn tất!"
}

# Tạo cấu hình 3proxy
generate_3proxy_config() {
    local proxy_count=$1
    local start_port=$2
    local use_auth=$3
    local username=$4
    local password=$5
    
    log "Tạo cấu hình 3proxy..."
    
    cat > /etc/3proxy/3proxy.cfg << EOF
# 3proxy configuration file
daemon
maxconn 3000
nserver 8.8.8.8
nserver 8.8.4.4
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# Log configuration
log /var/log/3proxy.log D
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"
rotate 30

# Access control
EOF

    if [[ "$use_auth" == "y" ]]; then
        echo "users $username:CL:$password" >> /etc/3proxy/3proxy.cfg
        echo "auth strong" >> /etc/3proxy/3proxy.cfg
        echo "allow $username" >> /etc/3proxy/3proxy.cfg
    else
        echo "auth none" >> /etc/3proxy/3proxy.cfg
        echo "allow * *" >> /etc/3proxy/3proxy.cfg
    fi
    
    echo "" >> /etc/3proxy/3proxy.cfg
    
    # Tạo proxy entries
    local counter=0
    while read -r ipv6 && [[ $counter -lt $proxy_count ]]; do
        local port=$((start_port + counter))
        echo "socks -6 -i$ipv6 -p$port" >> /etc/3proxy/3proxy.cfg
        ((counter++))
        
        if ((counter % 500 == 0)); then
            log "Đã tạo $counter/$proxy_count proxy configs..."
        fi
    done < ipv6_list.tmp
    
    log "Cấu hình 3proxy hoàn tất!"
}

# Tạo file proxy.txt
generate_proxy_file() {
    local proxy_count=$1
    local start_port=$2
    local use_auth=$3
    local username=$4
    local password=$5
    
    log "Tạo file proxy.txt..."
    
    > proxy.txt
    
    # Lấy IP public của VPS
    PUBLIC_IP=$(curl -s -4 ifconfig.me)
    
    for ((i=0; i<proxy_count; i++)); do
        local port=$((start_port + i))
        if [[ "$use_auth" == "y" ]]; then
            echo "$username:$password@$PUBLIC_IP:$port" >> proxy.txt
        else
            echo "$PUBLIC_IP:$port" >> proxy.txt
        fi
    done
    
    log "Đã tạo file proxy.txt với $proxy_count proxy!"
}

# Tạo file data.txt
generate_data_file() {
    local proxy_count=$1
    local start_port=$2
    local use_auth=$3
    local username=$4
    local password=$5
    
    log "Tạo file data.txt..."
    
    > data.txt
    
    PUBLIC_IP=$(curl -s -4 ifconfig.me)
    
    local counter=0
    while read -r ipv6 && [[ $counter -lt $proxy_count ]]; do
        local port=$((start_port + counter))
        if [[ "$use_auth" == "y" ]]; then
            echo "$username:$password@$PUBLIC_IP:$port -> $ipv6" >> data.txt
        else
            echo "$PUBLIC_IP:$port -> $ipv6" >> data.txt
        fi
        ((counter++))
    done < ipv6_list.tmp
    
    log "Đã tạo file data.txt!"
}

# Upload file lên file.io
upload_to_fileio() {
    local filename=$1
    log "Đang upload $filename lên file.io..."
    
    if [[ ! -f "$filename" ]]; then
        error "File $filename không tồn tại!"
        return 1
    fi
    
    local response=$(curl -s -F "file=@$filename" https://file.io)
    local download_link=$(echo "$response" | jq -r '.link' 2>/dev/null)
    
    if [[ "$download_link" != "null" && -n "$download_link" ]]; then
        echo -e "${GREEN}✓ Upload thành công: $download_link${NC}"
        return 0
    else
        error "Upload thất bại cho file $filename"
        return 1
    fi
}

# Khởi động 3proxy service
start_3proxy() {
    log "Khởi động 3proxy service..."
    
    # Tạo systemd service file
    cat > /etc/systemd/system/3proxy.service << EOF
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/3proxy /etc/3proxy/3proxy.cfg
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    # Tạo thư mục log
    mkdir -p /var/log
    
    # Reload systemd và start service
    systemctl daemon-reload
    systemctl enable 3proxy
    systemctl restart 3proxy
    
    if systemctl is-active --quiet 3proxy; then
        log "3proxy service đã khởi động thành công!"
    else
        error "Không thể khởi động 3proxy service!"
        exit 1
    fi
}

# Cấu hình firewall
configure_firewall() {
    local start_port=$1
    local proxy_count=$2
    
    log "Cấu hình firewall..."
    
    # Kiểm tra và cài đặt firewalld nếu cần
    if ! systemctl is-active --quiet firewalld; then
        dnf install -y firewalld >/dev/null 2>&1
        systemctl enable firewalld
        systemctl start firewalld
    fi
    
    # Mở range port cho proxy
    local end_port=$((start_port + proxy_count - 1))
    firewall-cmd --permanent --add-port=${start_port}-${end_port}/tcp >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
    
    log "Đã mở port $start_port-$end_port cho proxy!"
}

# Cleanup function
cleanup() {
    log "Dọn dẹp file tạm..."
    rm -f ipv6_list.tmp
}

# Hàm chính
main() {
    show_banner
    
    # Kiểm tra quyền root
    check_root
    
    # Input từ người dùng
    echo -e "${BLUE}Nhập số lượng proxy muốn tạo (mặc định: 2000):${NC}"
    read -r proxy_count
    proxy_count=${proxy_count:-2000}
    
    echo -e "${BLUE}Nhập port bắt đầu (mặc định: 40000):${NC}"
    read -r start_port
    start_port=${start_port:-40000}
    
    echo -e "${BLUE}Bạn có muốn sử dụng authentication? (y/n, mặc định: n):${NC}"
    read -r use_auth
    use_auth=${use_auth:-n}
    
    if [[ "$use_auth" == "y" ]]; then
        echo -e "${BLUE}Nhập username:${NC}"
        read -r username
        echo -e "${BLUE}Nhập password:${NC}"
        read -r password
        
        if [[ -z "$username" || -z "$password" ]]; then
            error "Username và password không được để trống!"
            exit 1
        fi
    fi
    
    # Validation
    if [[ ! "$proxy_count" =~ ^[0-9]+$ ]] || [[ $proxy_count -lt 1 ]]; then
        error "Số lượng proxy không hợp lệ!"
        exit 1
    fi
    
    if [[ ! "$start_port" =~ ^[0-9]+$ ]] || [[ $start_port -lt 1024 ]] || [[ $start_port -gt 65000 ]]; then
        error "Port không hợp lệ! (1024-65000)"
        exit 1
    fi
    
    log "Bắt đầu tạo $proxy_count proxy từ port $start_port..."
    
    # Thực hiện các bước
    install_requirements
    get_ipv6_info
    generate_ipv6_list $proxy_count
    configure_ipv6_addresses $proxy_count
    
    # Tạo thư mục cấu hình 3proxy
    mkdir -p /etc/3proxy
    
    generate_3proxy_config $proxy_count $start_port $use_auth $username $password
    start_3proxy
    configure_firewall $start_port $proxy_count
    
    # Tạo files output
    generate_proxy_file $proxy_count $start_port $use_auth $username $password
    generate_data_file $proxy_count $start_port $use_auth $username $password
    
    # Upload files
    echo -e "\n${BLUE}Đang upload files lên file.io...${NC}"
    upload_to_fileio "proxy.txt"
    upload_to_fileio "data.txt"
    
    # Cleanup
    cleanup
    
    # Thông báo hoàn thành
    echo -e "\n${GREEN}=================================================="
    echo "           HOÀN THÀNH TẠO PROXY!"
    echo "==================================================${NC}"
    echo -e "${GREEN}✓ Đã tạo: $proxy_count proxy${NC}"
    echo -e "${GREEN}✓ Port range: $start_port-$((start_port + proxy_count - 1))${NC}"
    echo -e "${GREEN}✓ Files: proxy.txt, data.txt${NC}"
    
    if [[ "$use_auth" == "y" ]]; then
        echo -e "${GREEN}✓ Authentication: $username:$password${NC}"
    else
        echo -e "${GREEN}✓ Authentication: Không${NC}"
    fi
    
    echo -e "\n${YELLOW}Lưu ý:${NC}"
    echo "- Files đã được upload lên file.io (link ở trên)"
    echo "- 3proxy service đang chạy"
    echo "- Kiểm tra status: systemctl status 3proxy"
    echo "- Log file: /var/log/3proxy.log"
}

# Trap để cleanup khi script bị ngắt
trap cleanup EXIT

# Chạy script
main "$@"
