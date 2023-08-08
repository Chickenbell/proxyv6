# proxyv6
>>>>chạy trên vps centos7 64, có hỗ trợ ipv6

>>>chạy lệnh sau để update vps:

*/ bác nào rảnh thì chạy, còn nếu vội thì bỏ qua cũng được :)

bước 1: yum update -y

đợi chạy xong đoạn trên thì chạy lệnh sau để restart vps: reboot

------------------------>>>> code chạy với vultr: <<<<<------------------------

bash <(curl -s "https://raw.githubusercontent.com/Chickenbell/proxyv6/main/v6vultr.sh")

chạy xong sẽ có 2000proxy, check ở dưới sẽ có link download proxy.

------------------------>>> code chạy với bkns: <<<<<------------------------

bước 1: set ipv6: 

curl -sO https://raw.githubusercontent.com/Chickenbell/proxyv6/main/setipv6.sh && bash setipv6.sh

bước 2: tạo proxy:

wget https://raw.githubusercontent.com/Chickenbell/proxyv6/main/setupbkns.sh && chmod +x setupbkns.sh && bash setupbkns.sh


tạo xong sẽ có 2000 proxy v6, có thể tìm file proxy trong thư mục home/bkns (dùng bitvise)

------------------------>>>> Code chạy với Cloudviet.vn. <<<<<------------------------

wget -qO- https://raw.githubusercontent.com/Chickenbell/proxyv6/main/setupv6cloudviet.sh | bash

------------------------>>>> Vpsttt <<<<<------------------------

wget https://raw.githubusercontent.com/Chickenbell/proxyv6/main/v6Vpsttt.sh && chmod +x v6Vpsttt.sh && bash v6Vpsttt.sh

------------------------>>>> lanit <<<<<------------------------
>>>> script 1:

curl -sO https://raw.githubusercontent.com/Chickenbell/proxyv6/main/ipv6lanit-nonepass.sh && chmod +x ipv6-with-port-none-password.sh && bash ipv6lanit-nonepass.sh

>>>> script 2:

yum update -y

wget -qO - https://file.lowendviet.com/Scripts/Linux/levip6/levip6 | bash <(cat) </dev/tty

Sau khi cài đặt phần mềm, quý khách sẽ được yêu cầu sử dụng lệnh levip6 để chạy lại phần mềm.

Sử dụng phần mềm
Sau khi cài đặt phần mềm, quý khách gõ levip6 để vào menu chính:
Bước 1: Tại giao diện của phần mềm, quý khách chọn menu 1 để kiểm tra xem tính năng IPv6 đã bật trên VPS hay chưa. Nếu chưa bật, quý khách chọn “Y” để bật lên.

Bước 2: Kiểm tra kết nối của IPv6. Quý khách chọn menu 5 để kiểm tra xem IPv6 có hoạt động hay chưa. Tại menu này, phần mềm sẽ thực hiện 2 kiểm tra:
Kết nối ra một trang check IP bên ngoài xem IPv6 hiện tại của quý khách là bao nhiêu
Ping tới ipv6.google.com xem mạng đã thông chưa
Nếu mạng đã thông, quý khách có thể tiến hành cài đặt IPv6 Proxy. Nếu mạng chưa thông, quý khách kiểm tra lại IPv6 chính hoặc liên hệ nhà cung cấp để kiểm tra cài đặt IPv6 đầu server.
Bước 3: Quý khách chọn menu 6 để cài đặt proxy. Quý khách sẽ được hỏi 2 câu hỏi:
Nhập số lượng proxy muốn khởi tạo. Mặc định phần mềm sẽ tạo 1 proxy. Quý khách nên tạo dưới 1000 proxy để đảm bảo ổn định. Trong ví dụ là cài 10 proxies.
Nhập proxy password. Nếu quý khách để trống, phần mềm sẽ tạo password ngẫu nhiên.
Sau khi cài đặt, quý khách sẽ nhận được 1 link download file proxy đã khởi tạo. File được nén với phần mềm zip, quý khách sử dụng mật khẩu được hiển thị để giải nén. Bất kì lúc nào, quý khách cũng có thể chạy lại phần mềm levip6 để thêm, bớt proxy (menu 7) nếu cần.Quý khách cũng có thể xem lại các proxy đã được khởi tạo bằng menu 8.

------------------------>>>> Cloudfly <<<<<------------------------
Cấu hình vps: 

IPV6ADDR="Lấy trong trang quản lý"

IPV6_DEFAULTGW="Lấy trong trang quản lý"

echo "IPV6_FAILURE_FATAL=no

IPV6_ADDR_GEN_MODE=stable-privacy

IPV6ADDR=$IPV6ADDR/64

IPV6_DEFAULTGW=$IPV6_DEFAULTGW" >> /etc/sysconfig/network-scripts/ifcfg-eth0

service network restart

>>>>Tạo proxy có pass:

curl -sO https://raw.githubusercontent.com/Chickenbell/proxyv6/main/cloudfly-ipv6-with-password.sh && chmod +x cloudfly-ipv6-with-password.sh && bash cloudfly-ipv6-with-password.sh

>>>>Tạo proxy Không pass:

curl -sO https://raw.githubusercontent.com/Chickenbell/proxyv6/main/cloudfly-ipv6-none-password.sh && chmod +x cloudfly-ipv6-none-password.sh && bash cloudfly-ipv6-none-password.sh

Lấy thông tin proxy ở: cd /home/cloudfly




