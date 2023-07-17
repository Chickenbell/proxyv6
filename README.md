# proxyv6
>>>>chạy trên vps centos7 64, có hỗ trợ ipv6

>>>chạy lệnh sau để update vps:

*/ bác nào rảnh thì chạy, còn nếu vội thì bỏ qua cũng được :)

bước 1: yum update -y

đợi chạy xong đoạn trên thì chạy lệnh sau để restart vps: reboot

>>>>code chạy với vultr:

bash <(curl -s "https://raw.githubusercontent.com/Chickenbell/proxyv6/main/v6vultr.sh")

chạy xong sẽ có 2000proxy, check ở dưới sẽ có link download proxy.

>>>code chạy với bkns:

bước 1: set ipv6: 

curl -sO https://raw.githubusercontent.com/Chickenbell/proxyv6/main/setipv6.sh && bash setipv6.sh

bước 2: tạo proxy:

wget https://raw.githubusercontent.com/Chickenbell/proxyv6/main/setupbkns.sh && chmod +x setupbkns.sh && bash setupbkns.sh


tạo xong sẽ có 2000 proxy v6, có thể tìm file proxy trong thư mục home/bkns (dùng bitvise)

>>>> Code chạy với Cloudviet.vn.

wget -qO- https://raw.githubusercontent.com/Chickenbell/proxyv6/main/setupv6cloudviet.sh | bash

>>>> Vpsttt

wget https://raw.githubusercontent.com/Chickenbell/proxyv6/main/v6Vpsttt.sh

chmod +x v6Vpsttt.sh && bash v6Vpsttt.sh
