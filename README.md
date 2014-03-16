Hướng dẫn cài đặt OpenStack Havana theo mô hình All In One
==============

Tham khảo kịch bản của tác giả Andriy Yurchuk tại link
- https://github.com/Ch00k/openstack-install-aio/blob/master/openstack-all-in-one.rst#id2

Người thực hiện:
- Trần Hoàng Sơn    tranhoangson@gmail.com
- VIỆT STACK        vietstack@gmail.com

## Chuẩn bị
Thiết lập thông số

## Thực hiện:
Chuyển sang quyền root bằng lệnh
- sudo - i hoặc su - 

Tải cài đặt gói git bằng lệnh
- apt-get install git -y

Tải script bằng lệnh và di chuyển vào thư mục havana-lab-aio
-  git clone https://github.com/vietstack/havana-lab-aio.git && cd havana-lab-aio

## Chạy script để thiết lập cấu hình cho các interface
- chmod -R 777 configure-network.sh
- sh configure-network.sh

## Chạy script để tiến hành cài đặt OpenStack 
- chmod -R 777 install-stack.sh
- sh install-stack.sh

## Liên hệ:
tranhoangson@gmail.com | vietstack@gmail.com | http://facebook.com/groups/vietstack
