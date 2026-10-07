# linux
> Ubuntu系统：学习C/C++的环境配置
1. 切换到 root 用户
   sudo -i
如果要求输入密码，正常输入即可。输入密码时终端不会显示任何字符，输入完成后回车即可。

3. 更新系统并安装 wget
   apt update
   apt upgrade -y
   apt autoremove -y
   apt install wget -y
4. 下载自己的环境配置脚本
改成自己的 GitHub 地址：
wget https://raw.githubusercontent.com/cdtcontact/linux-env/main/install.sh

5. 执行环境配置脚本
   bash install.sh
执行后等待配置完成即可。

7. 配置完成（总结）
以后新建 Linux 云服务器，只需要执行：
  sudo -i
  apt update
  apt upgrade -y
  apt autoremove -y
  apt install wget -y
  wget https://raw.githubusercontent.com/cdtcontact/linux-env/main/init_env.sh
  bash init_env.sh
这样就会直接使用你 GitHub 上自己的 Linux 配置脚本。
