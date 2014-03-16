================================
Hướng dẫn cài đặt OpenStack Havana theo mô hình All In One
================================

Hướng dẫn này dựa theo bài viết của tác giả `Andriy Yurchuk's <http://minuteware.net>`_ <ayurchuk@minuteware.net> `theo hướng dẫn này  <https://github.com/Ch00k/openstack-install-aio>`_

.. contents::

Người thực hiện

- Trần Hoàng Sơn    tranhoangson@gmail.com
- VIỆT STACK        vietstack@gmail.com

Yêu cầu về thiết bị
============

Thiết lập thông số
============
Hệ điều hành
----------------
Ubuntu 12.04 Server 64-bit

Phân vùng ổ đĩa
----
Hướng dẫn này phân vùng các ổ đĩa cho Ubuntu như sau, bước này thực hiện lúc cài đặ Ubuntu (bạn cần phân vùng đúng thứ tự như dưới)

=========  =======================  ==============  ===================
Partition  Filesystem               Mount point     Size
=========  =======================  ==============  ===================
/dev/sda1  swap                     n/a             (Amount of RAM) * 2
/dev/sda2  ext4                     /               30+ GB
/dev/sda3  none                     n/a             30+ GB
/dev/sda4  xfs                      /srv/node/sda4  10+ GB
=========  =======================  ==============  ===================

:Nics: eth0 (10.10.10.51), eth1 (192.168.1.251)

## Thực hiện:
Chuyển sang quyền root bằng lệnh
- sudo - i hoặc su - 

Tải cài đặt gói git bằng lệnh
- apt-get install git -y

Tải script bằng lệnh và di chuyển vào thư mục havana-lab-aio
-  git clone https://github.com/vietstack/havana-lab-aio.git && cd havana-lab-aio

Chạy script để thiết lập cấu hình cho các interface
- chmod -R 777 configure-network.sh
- sh configure-network.sh

Chạy script để tiến hành cài đặt OpenStack 
- chmod -R 777 install-stack.sh
- sh install-stack.sh

## Liên hệ:
tranhoangson@gmail.com | vietstack@gmail.com | http://facebook.com/groups/vietstack
