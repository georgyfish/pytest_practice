#!/bin/bash
#hhh
#install mc ; mc可以用来下载上传oss上的文件
function install_mc() {
	sudo wget --no-check-certificate -q http://oss.mthreads.com/installation-files/minio/2021-04-22/mc -O /usr/local/bin/mc; sudo chmod 755 /usr/local/bin/mc
	mc alias set oss https://oss.mthreads.com product-release  product-release123
	echo "mc install complete"
}

function install_tools() {
	dkms_build_env  #安装dkms编译环境
	install_decode_tool #安装解码库
	#安装ifconfig
	sudo apt-get install net-tools -y; #for ifconfig
	sudo apt-get install vim -y;
	sudo apt install -y mpv
	sudo apt install lightdm -y
}

function system_settings() {
	lightdm_autologin  #自动登录，提前安装lightdm
	disable_apt_update #禁用apt更新
	hold-kernel        #保持kernel版本
	disable_screen_blank  #禁用锁屏
}

#换源
function change_apt_source() {
	#sudo sed -i 
	#先备份
	sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
	sudo sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
	sudo apt update
}
#从U盘安装realtek r8125网卡驱动
function r8125_Kernel_54() {
	sudo cp /media/`hostname |awk -F- '{print $1}'`/Ventoy/r8125.ko /lib/modules/`uname -r`/kernel/drivers/net/ethernet/realtek/
	sudo depmod -a
	sudo modprobe r8125
	sleep 5
}

#检查网络
function net_check() {
	ip_add=$(ip addr |grep inet|grep -vE "docker0|wl|\<lo"|grep "192.168"|awk '{print $2}'|awk -F/ '{print $1}')
	if [ $ip_add != "127.0.0.1" ];then 
		echo $ip_add
	else
		echo "ip=$ip_add,未检测到DHCP分配ip"
		exit 1
	fi
	test_ip=192.168.114.118
	#检查是否有网络
	ping_result=`ping -c1 -W1 $test_ip > ping.txt 2>&1`
	#ping一次，超时时间1秒，ping的通返回0，echo up，ping失败打印down
	if [ $? -eq 0 ]
	then   
    	echo "可以ping通$test_ip..."
	else
    	echo "无法ping通$test_ip..."
    	exit 1
	fi
}

function build_r8125_dkms_driver() {
	echo "Download  r8125 driver"
 	wget http://192.168.114.118/tool/r8125-9.012.03.tar.bz2
	sudo tar -xvf r8125-9.012.03.tar.bz2 -C /usr/src
	cd /usr/src/r8125-9.012.03
	#需要提前安装编译环境dkms和build-essential
	dkms_build_env
	sudo ./autorun.sh
}


function disable_screen_blank() {
	#关闭显示器息屏、锁屏
	gsettings set org.gnome.desktop.session idle-delay 0
	gsettings set org.gnome.desktop.screensaver lock-enabled false

}


function hold-kernel() {
	#检查内核版本 `uname -r`，非dkms版本驱动需求内核版本为5.4.0-42；dkms版驱动支持多版本内核，无需配置到5.4；
	#check_kernel_version

	#如果是其他版本系统，初始内核是其他版本，需要下载内核；

	#设置apt-mark保持在内核5.4
	echo "内核5.4 .."
	sudo apt-mark hold linux-image-5.4.0-42-generic;
	sudo apt-mark hold linux-headers-5.4.0-42-generic;
}

function dkms_build_env() {
	sudo apt install devscripts debmake debhelper build-essential dkms -y
	sudo sed -i 's/# autoinstall_all_kernels/autoinstall_all_kernels/g' /etc/dkms/framework.conf  #修改dkms默认配置
}

# function install_dec_tool() {
# 	sudo apt install libdvdnav4 libdvd-pkg gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly libdvd-pkg -y;
# 	sudo apt-get install ubuntu-restricted-extras -y;

# }

function download_xctool() {
	cd /home/swqa/
	rm -f xc_tool.tgz
	echo "下载xc_tool.tgz"
	wget http://192.168.114.118/xc_tool.tgz
	echo "解压xc_tool.tgz"
	tar zxf xc_tool.tgz
}

function lightdm_autologin() {
	#lightdm自动登录
	lightdm_autologin_cmd="[SeatDefaults]\nautologin-user=swqa\n[LightDM]\nlogind-check-graphical=true\n" 
	#sudo echo -e $lightdm_autologin_cmd > /etc/lightdm/lightdm.conf
	#sudo bash -c 'echo -e $lightdm_autologin_cmd > /etc/lightdm/lightdm.conf'
	echo -e $lightdm_autologin_cmd |sudo tee /etc/lightdm/lightdm.conf  
}

function init() {
	x="$(pwd)"
	echo "工作路径：$x/xc_tool" 
	cd ~/xc_tool
	sed -i 's/install_ltp/#install_ltp/g' ~/xc_tool/init_xc_env.sh
	sed -i 's/function #install_ltp/function install_ltp/g' ~/xc_tool/init_xc_env.sh 
	sed -i 's/install_gfxbench/#install_gfxbench/g' ~/xc_tool/init_xc_env.sh
	sed -i 's/function #install_gfxbench/function install_ltp/g' ~/xc_tool/init_xc_env.sh 
	./init_xc_env.sh
}


function install_driver() {
	read -p "请输入分支名称: " branch
	read -p "请输入driver date_version: " version
	cd ~/xc_tool
	# branch=$1
	# version=$2
	while [ $branch = '' || $branch = ' ' ];do
		read -p "请输入分支名称: " branch
	done
	#判断version格式正确,20231220,年月日 format
	if [[ $version -ne '' ]];then
		pattern='^\d{8}$'  
		while [[ $version =~ $pattern ]];do 
			# echo "driver date_version格式不正确，请输入'20230101'类似格式"
			read -p "请输入正确格式的driver date_version: " version
		done
		version=`date -d $version +%Y%m%d`
		while [[ $? -ne 0 ]];do
			read -p "请输入正确格式的driver date_version: " version
		done
	fi
 	./download_driver.py $branch $version
	#check driver download--install--check install
	# xc_tool/driver/ deb包文件，检查下载成功？
	# install,参考ci pipeline musa_$date-D+$ID+dkms+glvnd-$os_$arch.deb

	# check-install 
}


function install_env() {
	#安装网卡驱动---联网成功--修改镜像源---下载xc_tool--执行初始化脚本--
	r8125_Kernel_54
	net_check
	change_apt_source
	#install_tools
	#system_settings
	download_xctool
	init
	install_mc
	build_r8125_dkms_driver
	#install_driver 
	echo "初始化环境成功！Need reboot to work!!!"
}

# read -r -p "请输入需要安装的驱动版本：" input
# #输入 不输入或者空格---默认是最新的驱动 当天日期`date +%Y%m%d`，日期格式`20230221`----版本`2023-02-22`,其他输入---提示格式错误
# if $input == '' | $input == ' '
# then 
# 	driver_version= `date +%Y%m%d` #最新驱动，默认最新日期来找，最新日期没有的话，往前找最新
# if echo $input | grep -Eq "[0-9]{4}[0-9]{2}[0-9]{2}" && date -d $input +%Y%m%d > /dev/null 2>&1 
# then 
# 	echo "输入格式正确"
# 	driver_version=`date -d $input +%Y%m%d`
# else
#   echo "输入的日期格式不正确，应为yyyymmdd";
#   exit 1;


install_env 
