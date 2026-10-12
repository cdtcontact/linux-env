# linux-env（老师配置的本地化整理版）

目标：把原配置链路中已经安装的 Vim、Vundle/插件、Oh My Zsh、Zsh 插件和旧安装脚本集中到自己的 GitHub 仓库。新版本安装流程只从本仓库获取配置，不再调用老师旧服务器上的 HTTP 地址。

> 注意：刚解压的工具包不包含你的实际 `.vim`、`.vimrc`、`.zshrc`、`.oh-my-zsh` 文件。需要先在已经装好老师环境的 Ubuntu 用户下运行收集脚本，再审核并推送仓库。不要在 payload 尚未收集完成前运行 `init_env.sh`。

## 1. 收集当前已安装的老师配置

在原来已经运行过老师安装流程、并且家目录仍保留这些文件的普通用户下执行：

```bash
sudo apt-get update
sudo apt-get install -y rsync file
cd ~/linux-env
bash scripts/collect_teacher_config.sh
bash scripts/audit_payload.sh
```

收集脚本会从当前用户家目录复制：

- `~/.vim/`：已下载的 Vim 插件和配置文件（排除嵌套 `.git`、swap 文件和机器生成的 `systags`）；
- `~/.vimrc`；
- `~/.zshrc`；
- `~/.oh-my-zsh/`：Oh My Zsh 核心、内置插件、自定义插件和主题（排除 Git 元数据、缓存和编译后的 zsh 字节码）；
- 如果存在，会把 `init_env.sh`、`isoftstone_env.sh`、`install_vim.sh`、`install_zsh.sh` 作为历史参考脚本归档在 `archive/legacy/`，新安装器不会执行它们。

收集器可选复制 `/usr/bin/isoftstone_check` 到 `payload/bin/` 供检查。该旧程序可能是针对 Ubuntu 18.04 或特定 CPU 架构编译的，默认不会被安装器自动执行；安装时还会再次询问。

## 2. 审核后再推送

```bash
cd ~/linux-env
bash scripts/audit_payload.sh
find payload/home/.vim/bundle -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
find payload/home/.oh-my-zsh/custom/plugins -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
```

重点检查 `.vimrc`、`.zshrc` 和 `archive/legacy/`，确认没有令牌、密码、私钥或个人路径。绝不复制 `~/.ssh/`、`.zsh_history`、`.viminfo`、`.zcompdump*` 等个人凭据或机器状态。

保留各第三方组件原有的 LICENSE/NOTICE 文件；来源线索见 `notes/THIRD_PARTY_SOURCES.md`。不要随意删除插件自身的许可文件。

当 GitHub 上新建好空仓库 `cdtcontact/linux-env` 后：

```bash
cd ~/linux-env
git init -b main
git add .
git status --short
git commit -m "Rebuild Linux environment configuration"
git remote add origin git@github.com:cdtcontact/linux-env.git
git push -u origin main
```

如果你已经在这个目录初始化过 Git，就不要重复 `git init`；先用 `git status` 和 `git remote -v` 检查。

## 3. 在全新 Ubuntu 上安装

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

## 4. 重要说明

- 这是针对当前老师配置的迁移工具包，不代表所有旧插件在现代 Ubuntu / 新版 Vim / 新版 Ruby 上一定仍兼容。
- `~/.vim/systags` 是本机系统头文件生成的索引，安装时重新生成，不入 Git。
- Command-T 等旧插件可能包含架构或 Ruby 版本相关的编译产物。若收集脚本提示存在 `.so`、`.o` 或 `.bundle`，请审核这些文件；跨架构部署时可能需要在目标机重新编译或弃用该插件。
- 初次部署前先在测试虚拟机验证；保留原有管理员 SSH 会话，确认新账号可登录后再断开。
# linux-env
