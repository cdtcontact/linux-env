# linux-env
## 1. 在全新 Ubuntu 上安装
确认完整 payload 已推送，而且仓库对克隆安装器可读后，才在新 Ubuntu 上运行：
```bash
sudo -i
apt-get update
apt-get install -y wget ca-certificates
wget -O /root/init_env.sh https://raw.githubusercontent.com/cdtcontact/linux-env/main/init_env.sh
bash /root/init_env.sh
```
安装器会克隆整个仓库，安装基础软件包，提示选择要配置的普通用户名；用户名不存在时会创建，若已存在则不会删除或重建。它会备份准备替换的 `.vim`、`.vimrc`、`.zshrc`、`.oh-my-zsh`，并在新建用户时尽可能复制调用者的 `authorized_keys`（只复制公钥，不复制私钥）。安装完成后先验证新用户登录，再关闭原连接。
安装器不会修改 `/etc/sudoers` 为免密码 sudo，也不会自动覆盖 `/etc/ssh/sshd_config`。主机名设置为可选项。
## 2. 重要说明
- 当前配置的迁移工具包，所有旧插件在现代 Ubuntu / 新版 Vim / 新版 Ruby 不一定仍兼容。
- `~/.vim/systags` 是本机系统头文件生成的索引，安装时重新生成，不入 Git。
- Command-T 等旧插件可能包含架构或 Ruby 版本相关的编译产物。若收集脚本提示存在 `.so`、`.o` 或 `.bundle`，请审核这些文件；跨架构部署时可能需要在目标机重新编译或弃用该插件。
- 初次部署前先在测试虚拟机验证；保留原有管理员 SSH 会话，确认新账号可登录后再断开。
# linux-env
