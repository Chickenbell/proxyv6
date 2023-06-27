# proxyv6
chạy trên vps centos7 64, có hỗ trợ ipv6

chạy lệnh sau để update vps:

yum update -y

reboot

code chạy với vultr:

bash <(curl -s "https://raw.githubusercontent.com/Chickenbell/proxyv6/main/v6vultr.sh")

code chạy với bkns:

b1: set ipv6: 

curl -sO https://raw.githubusercontent.com/Chickenbell/proxyv6/main/setipv6.sh && bash setipv6.sh

b2: tạo proxy:

wget https://raw.githubusercontent.com/Chickenbell/proxyv6/main/setupbkns.sh && chmod +x setupbkns.sh && bash setupbkns.sh


tạo xong sẽ có 2000 proxy v6

có thể tìm file proxy trong thư mục home

