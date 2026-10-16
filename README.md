# linux-env：Ubuntu C / C++ / Python 学习环境

一套可以通过 `bash init_env.sh` 安装和更新的终端开发环境，面向在 Ubuntu 云主机、虚拟机或其他 Ubuntu 环境中学习 C、C++、Python 的使用者。

当前维护的配置来自 [`config/`](config/)，安装逻辑位于 [`scripts/`](scripts/)。历史配置保留在 `archive/legacy/` 和 `payload/` 中供参考，当前安装流程不部署这些旧配置。

**第一次使用，先看「首次安装」；已经安装过，直接看「更新配置」。更新配置不需要重装 Ubuntu，也不需要删除自己的代码目录。**

| 你希望做什么 | 阅读位置 |
| --- | --- |
| 从 GitHub 或 Gitee 安装 | [首次安装](#install) |
| 设置纯英文主机名、用户名和密码 | [安装向导](#identity) |
| 把已有环境更新到最新版 | [更新配置](#update) |
| 了解 Vim 文件头、括号配对、快捷键 | [Vim 使用](#vim) |
| 理解 INSERT 模式的错误提示 | [代码诊断](#diagnostics) |
| 理解灰色建议、Tab 和 Enter | [Zsh 使用](#zsh) |
| 编译 C/C++、使用 Python 虚拟环境 | [C/C++](#cpp)、[Python](#python) |
| 保留自己的配置、恢复旧配置 | [个人定制](#custom)、[备份与恢复](#restore) |
| 安装失败或效果不符合预期 | [排查问题](#troubleshooting) |

## 目录

1. [支持范围与使用前提](#requirements)
2. [两个仓库的关系](#repositories)
3. [首次安装](#install)
4. [安装向导：主机名、账号与密码](#identity)
5. [安装后验证](#verification)
6. [已有环境如何更新](#update)
7. [安装了什么、修改了什么](#contents)
8. [命令行参数、下载来源与版本选择](#options)
9. [Vim：编辑、模板、配对与快捷键](#vim)
10. [Vim：错误和警告诊断](#diagnostics)
11. [Zsh：提示符、灰色建议与补全](#zsh)
12. [C / C++ 日常学习流程](#cpp)
13. [Python 日常学习流程](#python)
14. [tmux 会话管理](#tmux)
15. [Git 与 EditorConfig](#git)
16. [个人定制与配置加载](#custom)
17. [备份、恢复与旧目录处理](#restore)
18. [常见问题与排查](#troubleshooting)
19. [仓库结构、测试与双平台维护](#maintenance)

<a id="requirements"></a>
## 1. 支持范围与使用前提

### 1.1 支持的系统

安装器明确检查 `/etc/os-release`，只接受以下版本：

| 系统 | 安装器支持 | 自动测试方式 |
| --- | --- | --- |
| Ubuntu 22.04 LTS | 支持 | GitHub Actions 中的 Ubuntu 容器安装与交互测试 |
| Ubuntu 24.04 LTS | 支持 | 同上 |
| Ubuntu 26.04 LTS | 支持 | 同上 |

Debian、Linux Mint、CentOS、其他 Ubuntu 版本，以及 Windows 的 PowerShell、Git Bash，都不是此安装脚本的直接目标系统。WSL 用户应在上述版本的 **Ubuntu 发行版内部**运行命令。

云主机、虚拟机、WSL 和容器的系统权限可能不同。例如，受限制的容器可能不允许修改主机名；这种情况下可以在向导中直接回车保留主机名。容器测试通过并不代表每种云厂商镜像、SSH 客户端和终端显示效果都完全相同。

### 1.2 需要的条件

- 能在目标 Ubuntu 上获得 root 权限，通常通过 `sudo -i`。
- 能访问所选 Git 平台的文件下载地址、Git HTTPS 仓库，以及本机配置的 Ubuntu APT 软件源。
- 首次交互安装需要可用的终端；SSH 终端可以使用。
- 安装目标是 `root` 或普通开发账号，不支持系统服务账号。
- 目标账号的主目录必须存在、属于该账号，并且不能是目录符号链接。

日常编辑、编译和运行程序使用自己的普通账号即可。只有安装系统软件、部署公共工具等步骤需要 root。

### 1.3 默认提供的体验

- GCC/G++、Clang、CMake、Ninja、GDB 和 Python 虚拟环境等学习工具。
- Vim 新建源文件时的署名注释、常用头文件、括号和引号配对。
- Vim 光标所在行的细横线，以及所在列的灰色背景。
- C/C++ 和 Python 的后台代码诊断，以及适合 INSERT 模式的提示更新规则。
- Zsh 彩色提示符、实时灰色补全建议、Tab 补全和特定场景的 Enter 接受建议。
- tmux、Git、搜索工具和可选的手动项目模板。

安装器不会自动生成 C/C++/Python 学习项目，也不会自动创建 `~/code`。Vim 文件模板、手动项目模板、安装器自检使用的临时程序是三个不同的功能，后文分别说明。

<a id="repositories"></a>
## 2. 两个仓库的关系

| 平台 | 仓库 | 该平台入口的默认来源 |
| --- | --- | --- |
| GitHub | [peacecdt/linux-env](https://github.com/peacecdt/linux-env) | `github` |
| Gitee | [peacecdt/linux-env](https://gitee.com/peacecdt/linux-env) | `gitee` |

维护时使用的 SSH 地址是：

```text
git@github.com:peacecdt/linux-env.git
git@gitee.com:peacecdt/linux-env.git
```

**普通安装使用公开 HTTPS，不需要配置 GitHub/Gitee SSH 公钥，也不需要登录 Git 平台。** SSH 地址主要用于你自己克隆、开发或推送仓库。

两个仓库共享工具配置、安装逻辑、示例和使用文档，`init_env.sh` 中的默认来源分别保留为：

```bash
# GitHub 版本
DEFAULT_SOURCE=github

# Gitee 版本
DEFAULT_SOURCE=gitee
```

因此：

- 从 GitHub 下载入口，后续默认从 GitHub 获取配置。
- 从 Gitee 下载入口，后续默认从 Gitee 获取配置。
- 不会因某个平台访问失败而自动切换到另一平台。
- APT 软件包从你机器现有的 Ubuntu 软件源安装，与 Git 平台的选择无关。
- 文档中的另一平台链接、归档文件中的旧 GitHub 链接，不等于当前安装器会访问这些链接。

自定义来源和优先级见[参数说明](#options)。

<a id="install"></a>
## 3. 首次安装

### 3.1 进入 Ubuntu，准备下载工具

在目标 Ubuntu 的终端中执行：

```bash
sudo -i

apt update
apt install wget ca-certificates -y
```

如果你本来就计划升级系统和清理不再需要的依赖，可以另外执行：

```bash
apt upgrade -y
apt autoremove -y
```

这两条是系统维护操作，不是环境安装的必需步骤。安装器自身会更新 APT 索引、安装所需软件包，但不执行整机 `apt upgrade` 或 `apt autoremove`。

### 3.2 选择一个平台的入口

下面两种方式任选一种即可，不需要连续安装两次。

**方式 A：GitHub**

```bash
wget -O init_env.sh https://raw.githubusercontent.com/peacecdt/linux-env/main/init_env.sh &&
bash init_env.sh
```

**方式 B：Gitee**

```bash
wget -O init_env.sh https://raw.giteeusercontent.com/peacecdt/linux-env/raw/main/init_env.sh &&
bash init_env.sh
```

如果 Gitee 的上述文件域名不可用，可改用同平台备用入口：

```bash
wget -O init_env.sh https://gitee.com/peacecdt/linux-env/raw/main/init_env.sh &&
bash init_env.sh
```

这里使用 `-O init_env.sh`，避免重复下载得到 `init_env.sh.1`、却继续执行旧脚本。使用 `&&`，让第二条命令只在下载成功后执行。

### 3.3 跟随向导完成安装

在正常交互终端中，脚本会询问主机名、开发账号和密码设置。随后安装依赖、部署配置、设置登录 Shell，并运行自检。

第一次下载入口后还需要获取仓库、安装软件包；耗时取决于网络、软件源和主机性能，没有固定的完成时间。

安装结束时会显示类似：

```text
[linux-env] 安装完成。重新登录，或运行: su - peacecdt
[linux-env] 环境已就绪；不会自动创建项目目录。
```

### 3.4 切换到开发账号

假设你选择的账号是 `peacecdt`：

```bash
su - peacecdt
```

也可以退出后重新使用该账号登录。以后编辑代码、编译程序、创建虚拟环境，都在这个普通账号下进行。

下文的 `peacecdt` 是示例账号，请按实际用户名替换；它不是安装器强制创建的固定账号。

<a id="identity"></a>
## 4. 安装向导：主机名、账号与密码

### 4.1 主机名规则

交互输入的新主机名要求：

- 只含 `A–Z`、`a–z`。
- 长度为 1–63 个字符。
- 大写自动转成小写。
- 不接受数字、空格、下划线或连字符。
- 直接回车保留当前主机名，即使旧主机名不符合这个新名称规则。

例如：

| 输入 | 结果 |
| --- | --- |
| `myubuntu` | 设置为 `myubuntu` |
| `TencentCloud` | 设置为 `tencentcloud` |
| `ubuntu01` | 拒绝，重新输入 |
| `my-server` | 拒绝，重新输入 |
| 直接回车 | 保留当前主机名 |

设置时会备份 `/etc/hostname` 和 `/etc/hosts`，更新系统主机名及 `127.0.1.1` 的本机解析。已有 hosts 内容会尽量保留，而不是把整份文件替换成一个空白模板。

如果检测到 `/etc/cloud/cloud.cfg`，还会写入：

```text
/etc/cloud/cloud.cfg.d/99-linux-env-hostname.cfg
```

内容为：

```yaml
preserve_hostname: true
manage_etc_hosts: false
```

这用于让 cloud-init 保留本次设置的主机名和 hosts。已有同名配置会先备份。

### 4.2 开发账号如何选择

可以选择已有普通用户，也可以在向导中输入一个新用户名。

默认账号的来源：

1. 传入了 `--user` 时，使用指定的已有账号作为默认值。
2. 否则，如果 `SUDO_USER` 指向有效的非 root 账号，使用该账号。
3. 没有可用的 sudo 调用者信息时，默认 root。

**请留意向导中显示的默认账号。** 从云厂商控制台直接以 root 登录，与通过普通用户执行 `sudo -i`，默认选择可能不同。

新用户名必须以小写英文字母开头，只能包含小写字母、数字、下划线和连字符，长度不超过 32 个字符。例如 `peacecdt`、`student01`、`cpp_learner`。

已有账号不会被删除、重建或重命名。脚本不接管系统服务账号；新建账号时，如果 `/home/用户名` 已存在，也会要求换一个用户名，避免接管原目录。

### 4.3 密码和 sudo 权限

| 选择 | 行为 |
| --- | --- |
| 新建普通用户 | 创建主目录，调用系统 `passwd` 设置密码，成功后加入 `sudo` 组 |
| 选择已有用户 | 询问是否修改密码，默认 `N`，保持原密码 |
| 无交互安装 | 保留主机名和密码，只配置已有账号 |

密码由系统 `passwd` 直接在终端中接收，输入时不显示字符，不作为脚本参数、环境变量或安装日志内容保存。

新用户的 sudo 操作仍需要输入该用户的密码，安装器不配置免密 sudo。已有账号的 sudo 权限保持原状，不会因为选择了该账号就自动授予管理员权限。

如果新账号已创建，但密码设置被中断，脚本会把账号保持锁定且不加入 sudo 组，并在输出中给出后续处理命令；账号不会假装已经可以正常登录。

### 4.4 云主机登录注意点

安装器不会复制 SSH 密钥，也不会修改 SSH 服务的密码登录策略。因此：

- 设置 Linux 用户密码，不等于云主机已经允许 SSH 密码登录。
- 原来只允许密钥登录的主机，仍需要为新账号按实际要求配置公钥或登录策略。
- 创建新账号后，可以先在现有 root 会话中使用 `su - 用户名` 验证本地登录，再用另一个终端验证远程登录。

脚本不会修改你的 `~/.ssh`。

<a id="verification"></a>
## 5. 安装后验证

在目标开发账号下执行：

```bash
whoami
hostname
echo "$HOME"
getent passwd "$(whoami)"
echo "$SHELL"
ps -p $$ -o comm=

linux-env-doctor
```

- `whoami`：确认现在使用哪个账号。
- `hostname`：确认主机名。
- `getent passwd` 最后一列：账号登记的登录 Shell。
- `echo "$SHELL"`：当前会话继承的登录 Shell 信息。
- `ps -p $$ -o comm=`：确认当前实际运行的 Shell。

`linux-env-doctor` 会：

1. 检查开发命令和 ALE 插件是否存在。
2. 在临时目录中编译并运行一个很小的 C 程序。
3. 编译并运行一个很小的 C++ 程序。
4. 创建临时 Python 虚拟环境，检查 `ssl`、`sqlite3`、`venv` 和 pip。
5. 检查 Zsh 语法和实际启动。
6. 检查 Vim 配置及 ALE 是否加载。
7. 退出时删除该临时自检目录。

成功时会看到 `C OK`、`C++ OK`、`Python venv OK`、`Zsh OK` 和最后的 `[OK]`。

自检不会运行你正在学习的项目。它验证基础环境可用，不能代替某个项目自己的编译、测试，也不等于完整的仓库 CI。

可以进一步查看工具版本：

```bash
gcc --version
g++ --version
clang --version
python3 --version
vim --version
zsh --version
tmux -V
```

具体版本跟随当前 Ubuntu 软件源，仓库不固定这些工具的每个版本号。

<a id="update"></a>
## 6. 已有环境如何更新

### 6.1 推荐方式：更新配置并检查安装依赖

先保存并退出正在编辑的 Vim，再进入 root。下面以已有账号 `peacecdt` 为例。

**GitHub：**

```bash
sudo -i
wget -O init_env.sh https://raw.githubusercontent.com/peacecdt/linux-env/main/init_env.sh &&
bash init_env.sh --non-interactive --user peacecdt
su - peacecdt
```

**Gitee：**

```bash
sudo -i
wget -O init_env.sh https://raw.giteeusercontent.com/peacecdt/linux-env/raw/main/init_env.sh &&
bash init_env.sh --non-interactive --user peacecdt
su - peacecdt
```

`--non-interactive` 表示这次不询问主机名、创建账号或修改密码。它仍会更新受管理配置，默认仍将目标账号的登录 Shell 设置为 Zsh。

此方式适合第一次更新、很久没有更新，或者新功能新增了 APT 依赖的情况。以前没有安装过代码诊断的环境，需要通过完整更新安装 `vim-ale` 和 `flake8`。

### 6.2 已有全部依赖，只更新配置

先按所选平台重新下载入口，然后执行：

```bash
bash init_env.sh --non-interactive --user peacecdt --skip-packages
su - peacecdt
```

`--skip-packages` 会跳过 APT 安装阶段，但不会跳过必需命令、ALE 插件和 fzf 集成文件检查。缺少依赖时会报错；这时去掉该参数重试即可。

### 6.3 什么时候新配置才生效

| 组件 | 更新后如何加载 |
| --- | --- |
| Zsh | 新登录一次，或在目标用户的终端中 `exec zsh` |
| Vim | 保存退出，再重新打开 Vim |
| tmux | 在 tmux 内按 `Ctrl+b` 后按 `r`，或运行 `tmux source-file ~/.tmux.conf` |
| Git | 后续 Git 命令会读取更新后的配置 |
| 已经创建的项目 | 项目源码不会被重新生成或同步覆盖 |

仅仅下载新的 `init_env.sh` 不会更新环境，必须执行它。已经打开的 Vim 和已有 Zsh 会话，也不会因为文件被替换就自动加载全部新行为。

### 6.4 重复运行会怎样

- 受管理的配置内容与现有文件相同，且目标是普通文件时，不重复备份或替换。
- 内容变化时，先备份原文件，再部署新文件。
- Git 的同一个 include 不会重复添加。
- `.local` 个人配置不会被安装器覆盖。
- 不删除学习项目，不自动生成项目目录。
- 指定 `--no-change-shell` 时保留目标账号原登录 Shell。

<a id="contents"></a>
## 7. 安装了什么、修改了什么

### 7.1 软件包

默认通过 APT 安装以下软件包，使用 `--no-install-recommends`：

| 分类 | 软件包 |
| --- | --- |
| 下载与基础工具 | `ca-certificates`、`git`、`curl`、`wget`、`file`、`unzip`、`zip`、`locales`、`bsdutils` |
| 账号与主机名 | `sudo`、`hostname`、`passwd` |
| C/C++ 编译与构建 | `build-essential`、`clang`、`cmake`、`ninja-build`、`pkg-config` |
| C/C++ 辅助工具 | `clangd`、`clang-format`、`clang-tidy`、`gdb` |
| 文档与索引 | `man-db`、`manpages-dev`、`universal-ctags` |
| Python | `python3`、`python3-dev`、`python3-pip`、`python3-venv`、`pipx`、`flake8` |
| 编辑器与终端 | `vim`、`vim-ale`、`zsh`、`tmux` |
| 搜索与脚本检查 | `ripgrep`、`fzf`、`shellcheck` |
| Zsh 插件 | `zsh-autosuggestions`、`zsh-syntax-highlighting` |
| 可选工具 | 软件源提供候选包时安装 `valgrind` |

`build-essential` 提供 GCC/G++ 等基础构建依赖。若现有软件源中找不到 `zsh-autosuggestions`，安装器会安装 `software-properties-common` 并启用 Ubuntu `universe` 组件，再更新索引。

安装器不会自动把 Ubuntu 源换成某个镜像站，也不会修改 pip 镜像。安装 `locales` 不代表脚本替你选择了中文语言、生成了特定地区配置或改变了系统时区。

### 7.2 文件部署位置

| 路径 | 用途 |
| --- | --- |
| `~/.vimrc` | 当前 Vim 主配置 |
| `~/.zshrc` | 当前 Zsh 主配置 |
| `~/.tmux.conf` | 当前 tmux 主配置 |
| `~/.config/linux-env/gitconfig` | Git 通用默认配置 |
| `~/.config/linux-env/editorconfig` | 供项目使用的 EditorConfig 模板 |
| `/usr/local/share/linux-env/config/` | 安装时保存的公共配置副本 |
| `/usr/local/share/linux-env/examples/` | 手动项目模板 |
| `/usr/local/share/linux-env/fzf/` | APT 提供的 fzf 集成脚本备用副本 |
| `/usr/local/share/linux-env/configure-home.sh` | 给目标账号部署配置的脚本 |
| `/usr/local/bin/linux-env-doctor` | 环境自检命令 |
| `/usr/local/bin/linux-env-new` | 手动创建项目模板的命令 |
| `/var/log/linux-env/` | 安装器阶段的日志 |
| `/run/lock/linux-env.lock` | 防止两个正式安装阶段同时运行的锁 |

这里的 `~` 指**选中的开发账号的主目录**，不一定是 `/root`。用户配置由该账号自身权限写入，避免生成只能由 root 修改的个人配置文件。

一次安装只更新选中账号的个人配置；公共工具和 `/usr/local/share/linux-env/` 为系统共享。要让另一个已有账号使用同一套最新版配置，需要再用 `--user 另一个账号` 为它执行一次部署。

### 7.3 安装阶段概览

1. 解析参数，检查系统及权限。
2. 若入口是单独下载的文件，准备 Git 和证书，获取所选仓库。
3. 检查配置是否完整，确定交互模式及目标账号。
4. 开始记录安装日志，并取得安装锁。
5. 收集向导选择，安装依赖，检查所需命令。
6. 按选择创建账号、设置密码、修改主机名。
7. 部署公共文件，再为目标账号备份和部署个人配置。
8. 默认将目标账号的登录 Shell 改为 Zsh。
9. 默认运行环境自检。

下载阶段使用浅层获取、`--filter=blob:none` 和稀疏检出，工作区只展开 `config/`、`scripts/`、`examples/` 等当前安装所需内容。实际节省的下载流量取决于 Git 服务端是否支持部分克隆过滤，不能把稀疏检出理解为所有服务器都保证只传输这些文件。

入口使用 `/tmp/linux-env.XXXXXXXX` 临时目录，结束后清理。下载失败等发生在正式安装器启动之前的问题，可能只出现在终端中，不一定已经生成安装日志。

<a id="options"></a>
## 8. 命令行参数、下载来源与版本选择

### 8.1 参数速查

```bash
bash init_env.sh --help
```

| 参数 | 作用 | 使用条件或补充 |
| --- | --- | --- |
| `--help` / `-h` | 显示帮助和入口默认来源 | 查看帮助不需要 root |
| `--source github` | 后续配置使用 GitHub 默认仓库 | 只接受 `github` 或 `gitee` |
| `--source gitee` | 后续配置使用 Gitee 默认仓库 | 不影响 APT 来源 |
| `--user alice` | 指定已有目标账号，或交互向导的默认账号 | 该账号必须先存在；新账号在向导中创建 |
| `--interactive` | 强制开启身份设置向导 | 必须有可用控制终端 |
| `--non-interactive` | 不开启向导 | 不创建账号、不改密码、不改主机名 |
| `--no-change-shell` | 保留账号原来的登录 Shell | 仍部署 Zsh 配置，仍可手动使用 Zsh |
| `--skip-packages` | 跳过 APT 阶段 | 不会补装缺失依赖 |
| `--skip-checks` | 跳过最后的环境自检 | 不跳过前面的系统、账号、文件和必需命令检查 |

`--interactive` 与 `--non-interactive` 不能同时使用。没有指定这两个参数时，标准输入和输出都是终端才默认开启向导，否则按无交互模式运行。

例如，为已有用户更新配置，同时保持其登录 Shell：

```bash
bash init_env.sh --non-interactive --user alice --no-change-shell
```

需要重新进入主机名和密码向导时：

```bash
bash init_env.sh --interactive --user alice
```

`--user alice` 不是创建账号的参数。如果 `alice` 尚不存在，应先用一个有效的默认账号进入向导，再在「开发用户名」处输入 `alice`。

### 8.2 环境变量和优先级

| 变量 | 默认值 | 作用 |
| --- | --- | --- |
| `LINUX_ENV_SOURCE` | 当前入口的 `DEFAULT_SOURCE` | 选择 `github` 或 `gitee` |
| `LINUX_ENV_REPO_URL` | 所选平台对应的本仓库 HTTPS 地址 | 显式指定另一个仓库 |
| `LINUX_ENV_REF` | `main` | 获取分支、标签或提交 SHA |

来源选择顺序是：

1. `--source` 优先于 `LINUX_ENV_SOURCE`。
2. 没有以上设置时，使用入口所属平台的默认值。
3. 如果设置了 `LINUX_ENV_REPO_URL`，实际仓库地址使用该变量，而不是平台默认地址；来源参数本身仍须合法。
4. `LINUX_ENV_REF` 决定从所选仓库取得哪个版本。

```bash
# 在当前 root 终端中，为这次执行指定来源
LINUX_ENV_SOURCE=gitee bash init_env.sh --non-interactive --user peacecdt

# 命令行优先于上面的来源环境变量
LINUX_ENV_SOURCE=gitee bash init_env.sh --source github --non-interactive --user peacecdt

# 使用自己的 fork；将“你的账号”替换成实际仓库所有者
LINUX_ENV_REPO_URL=https://gitee.com/你的账号/linux-env.git \
  bash init_env.sh --non-interactive --user peacecdt
```

来源变量请在实际执行脚本的 root 会话中设置；不要假定普通用户环境中的变量一定会经过 `sudo -i` 保留下来。

### 8.3 固定某个版本

要固定版本，入口和后续配置都应使用同一个分支、标签或提交。下面用 GitHub 举例，先把示例值替换为仓库中真实存在的引用：

```bash
ref='填写真实的标签或提交SHA'
wget -O init_env.sh "https://raw.githubusercontent.com/peacecdt/linux-env/$ref/init_env.sh" &&
LINUX_ENV_REF="$ref" bash init_env.sh --non-interactive --user peacecdt
```

使用 Gitee 时，同样从 Gitee 对应引用下载入口，并把 `LINUX_ENV_REF` 设为该引用。不要默认两个仓库的 `main` 提交 SHA 相同：入口的平台默认值不同，提交也可能不同。

### 8.4 从本地克隆运行

已克隆仓库的情况下，在仓库根目录执行：

```bash
sudo bash init_env.sh --non-interactive --user peacecdt
```

如果入口所在目录同时有 `scripts/install.sh` 和 `config/vimrc`，脚本会直接使用旁边的本地配置。此时 `--source`、`LINUX_ENV_REPO_URL`、`LINUX_ENV_REF` **不会替你下载或更新这份本地工作区**；先自行更新仓库，再运行安装器。

`scripts/install.sh` 是内部安装脚本，不接收入口专用的 `--source`。一般使用根目录 `init_env.sh` 即可。

<a id="vim"></a>
## 9. Vim：编辑、模板、配对与快捷键

### 9.1 最基本的编辑步骤

```bash
vim test.c
```

进入 Vim 后，默认处于普通模式：

| 按键或命令 | 作用 |
| --- | --- |
| `i` | 在光标位置进入 INSERT 模式 |
| `a` | 在光标之后进入 INSERT 模式 |
| `o` | 在下一行新开一行并进入 INSERT |
| `Esc` | 回到普通模式 |
| `:w` 后回车 | 保存文件 |
| `:q` 后回车 | 退出；有未保存修改时会阻止退出 |
| `:wq` 后回车 | 保存并退出 |
| `:q!` 后回车 | 放弃当前未保存修改并退出 |
| `u` | 普通模式撤销 |
| `Ctrl+r` | 普通模式重做 |
| `/内容` 后回车 | 搜索；`n` / `N` 查找下一处 / 上一处 |
| `gg` / `G` | 到文件开头 / 末尾 |
| `:20` 后回车 | 跳到第 20 行 |

这里是 Vim 的模式操作；终端里输入 `vim te` 时的灰色建议属于 Zsh，见后面的 Shell 说明。

### 9.2 新文件注释模板

只对以下**尚不存在的新文件**自动插入模板：

```text
*.c  *.cpp  *.cc  *.cxx  *.py
```

已有文件不会被重写，已有的空文件也不会自动补模板。`.h`、`.hpp` 等头文件不在自动文件模板范围内。

例如新建 `test.c` 时会得到文件注释和以下常用头文件：

```c
/***********************************************************************
 * > File Name: test.c
 * > Author: chendatao
 * > Mail: peacecdt@gmail.com
 * > Created Time: 2026-10-16 10:00:00 CST
 **********************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
```

上面的时间只是格式示例。实际使用文件名和主机当前的本地时间、时区；脚本不会为生成注释而修改系统时间或时区。

新建 C++ 文件时，同样生成注释，然后按以下顺序插入头文件和命名空间声明：

```cpp
#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <queue>
#include <stack>
#include <algorithm>
#include <string>
#include <map>
#include <set>
#include <vector>
using namespace std;
```

新建 Python 文件时，模板包括：

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# **********************************************************************
# > File Name: test.py
# > Author: chendatao
# > Mail: peacecdt@gmail.com
# > Created Time: 2026-10-16 10:00:00 CST
# **********************************************************************

import sys
from pathlib import Path
```

这些内容最初只在 Vim 缓冲区中，执行 `:w` 后才写入磁盘；直接放弃退出，不会为了模板创建一个空项目。模板不插入 `main()` 函数，你可以按练习内容自行编写。

作者和邮箱可以通过 `~/.vimrc.local` 修改，见[个人定制](#custom)。

### 9.3 括号和引号自动配对

这是配置内置的 Vim 功能，不依赖网络下载配对插件，可用于普通编辑缓冲区的不同语言文件。

| 输入或动作 | 默认效果 |
| --- | --- |
| 输入 `(`、`[`、`{` | 补上对应右括号，光标留在中间 |
| 输入双引号、单引号、反引号 | 在适合的上下文中补齐另一侧 |
| 光标右侧已经是对应闭合符号，再输入该符号 | 越过已有符号，避免重复插入 |
| 空配对中按退格 | 同时删除两边 |
| 空的 `()`、`[]`、`{}` 中按 Enter | 展开为多行，按文件类型缩进 |
| Python 中继续输入三引号 | 支持三引号配对 |

配置会处理转义引号、字符串内部的另一种引号、单词中的撇号等常见情况。它不是完整的语言解析器；`<` 和 `>` 不在自动配对列表中，避免把比较表达式误当成括号。

需要按原样粘贴时：

```vim
:set paste
```

粘贴结束后恢复：

```vim
:set nopaste
```

长期关闭配对，在 `~/.vimrc.local` 中添加：

```vim
let g:linux_env_auto_pairs = 0
```

### 9.4 十字定位线与显示

- 横向：当前行底部的一条细下划线，不是整行铺满背景色。
- 纵向：光标所在列的灰色背景。
- 代码原来的语法颜色保留，深色和浅色背景分别使用合适的列底色。
- 行号为普通绝对行号。
- 左侧保留诊断标记栏，避免出现错误时整段代码横向跳动。
- 状态栏显示文件、修改状态、文件类型、行列位置和文件进度。

临时关闭定位线：

```vim
:set nocursorline nocursorcolumn
```

恢复：

```vim
:set cursorline cursorcolumn
```

横线的具体粗细、颜色和字体最终由终端渲染；不同 SSH 客户端不一定与截图像素一致。

### 9.5 本配置的快捷键

下面的 `空格` 是 Vim 普通模式中的 Leader 键。例如先按 `Esc`，再按空格，松开后按 `w`。

| 按键 | 对应命令 | 作用 |
| --- | --- | --- |
| 空格 → `w` | `:write` | 保存 |
| 空格 → `b` | `:make` | 调用当前文件类型的构建或语法检查 |
| 空格 → `q` | `:copen` | 打开构建 / 搜索的 quickfix 列表 |
| 空格 → `e` | `:Lexplore` | 打开左侧文件浏览器 |
| 空格 → `n` | `:nohlsearch` | 清除当前搜索高亮 |
| `]q` / `[q` | `:cnext` / `:cprevious` | 下一条 / 上一条 quickfix 结果 |
| `]d` / `[d` | ALE 下一条 / 上一条 | 跳转代码诊断，可循环 |

**`空格 q` 与 `:lopen` 不是同一个列表。** 前者主要查看构建、搜索的 quickfix 结果；后者查看当前窗口的 ALE 代码诊断。

### 9.6 缩进、搜索和标签跳转

- 默认 4 个空格缩进，Tab 转为空格。
- Shell、YAML、JSON 使用 2 个空格；Makefile 使用真实 Tab。
- 搜索默认忽略大小写，但搜索内容包含大写时区分大小写。
- `:grep` 使用已安装的 `rg`；结果可在 `:copen` 中查看。
- Vim 自带文件浏览器采用树形列表。
- 项目 tags 会向父目录查找，不会在启动时递归扫描整个 `/usr/include`。

在项目根目录建立 tags 后，可以使用原生标签跳转：

```bash
ctags -R --exclude=build --exclude=.venv .
```

回到 Vim，将光标放在符号上，按 `Ctrl+]` 跳转，`Ctrl+t` 返回。代码发生变化后，需要重新生成 tags。

### 9.7 `:make` 的实际行为

| 文件类型 | 默认行为 | 前提 |
| --- | --- | --- |
| C / C++ | `cmake --build build` | 已经配置好 CMake 构建目录，并在正确工作目录打开 Vim |
| Python | 用选中的 Python 执行 `-m py_compile` | 先保存当前文件；只检查语法，不运行程序 |

`空格 b` 不会自动保存文件，也不会把任意单个 `test.c` 自动变成 CMake 项目。单文件练习可以先 `:w`，再在终端使用 GCC/G++；多文件项目先配置 `build`。

Python 的 `:make` 每次执行时重新选择解释器：从当前文件所在目录向上寻找最近的 `.venv/bin/python`，然后尝试 `$VIRTUAL_ENV/bin/python`，最后使用 `python3`。语法编译可能生成 `__pycache__`，但不会执行这个 Python 文件。

<a id="diagnostics"></a>
## 10. Vim：错误和警告诊断

### 10.1 默认检查器

| 语言 | 诊断后端 | 默认设置 |
| --- | --- | --- |
| C | ALE 调用 Clang | `-std=c17 -Wall -Wextra` |
| C++ | ALE 调用 Clang++ | `-std=c++17 -Wall -Wextra` |
| Python | ALE 调用 APT 安装的 Flake8 | `--select=E9,F63,F7,F82` |

ALE 由 Ubuntu 的 `vim-ale` 软件包提供。默认开启的诊断语言只有 C、C++、Python。括号配对也可用于其他语言，语法着色则取决于 Vim 自带或你另外安装的语法支持；这些编辑功能不代表对应语言的诊断器也已安装和配置。

Python 默认主要检查语法、未定义名字和部分易错表达式，不把行长、普通空白风格等所有提示都开启。Flake8 使用系统安装版本进行静态检查，不导入和运行你的项目。

虽然安装了 `clangd`、`clang-format` 和 `clang-tidy`，当前 Vim 默认没有接入 clangd 的 LSP 智能补全，也不在保存时自动格式化或自动修复代码。括号配对与语义补全是不同的功能。

### 10.2 怎样看提示

| 显示 | 含义 |
| --- | --- |
| 左侧 `>>` | 错误 |
| 左侧 `!!` | 警告 |
| 问题处的高亮 / 下划线 | 诊断指向的位置或范围 |
| 底部文字 | 光标当前所在问题行的具体原因 |

底部文字跟随**当前光标所在行**，不会把上一行的错误说明永久固定在无关行下面。即使光标离开错误行，已确认的标记和问题列表仍会保留。

INSERT 模式下，底部显示错误原因时，可能暂时看不到 `-- INSERT --`。这是为了让错误说明留在同一消息区域，**实际仍处于 INSERT 模式，可以继续输入**。错误说明清除后恢复模式提示。

终端较窄时底部文字会截断；可以用问题列表查看完整内容。

### 10.3 INSERT 模式的更新规则

| 你的操作 | 配置如何处理 |
| --- | --- |
| 第一次在尚未诊断的新行输入 | 暂不展示这一行的新问题，允许把代码写完 |
| 按方向键或 Enter 移到其他行 | 检查刚完成编辑的内容 |
| 其他行已有已确认错误，此时输入空格、字符或新代码 | 不会仅因为按键就清空原有错误 |
| 在错误行上方插入一行 | 已有标记跟随原代码行移动 |
| 返回已检查的错误行，只移动光标 | 保留标记，底部显示原因 |
| 修改已确认的问题，但仍未修正 | 继续保留或更新诊断 |
| 已有已确认问题，或正在修正已确认问题时，修改后停止输入约 0.4 秒 | 重新检查当前未保存的缓冲区，仍抑制首次编写行的新问题；检查器运行时间另计 |
| 最新检查确认问题已修正 | 自动移除对应提示，不必离开原行，也不必退出 INSERT |
| 保存文件或退出 INSERT | 执行完整检查 |

这里的「写完」主要由换行、离开当前行、保存、退出 INSERT 等操作体现。脚本不会凭一个分号就猜测任意语言的一条语句是否完成。

未写完的新代码有时会让编译器停止继续分析。此时保守地保留已有错误，等离开新行或新的检查确认代码正确后再更新，避免把「这次没分析到」误认为「已经修好」。旧版本缓冲区的后台检查会被取消或忽略，不能覆盖新结果。

### 10.4 错误修正与警告的区别

例如：

```c
int a;
printf("%d\n", a);
```

可能提示使用了未初始化变量。把第一行改为：

```c
int a = 0;
```

重新检查后，相应的未初始化问题可以消失。

但如果代码只有 `int a = 0;`，后面没有使用 `a`，提示 `unused variable 'a'` 是「变量未使用」。赋初值并不等于使用变量，这类仍然成立的警告会保留。

同样，给变量赋值不会修复另一个变量未声明、函数实参数量错误、格式字符串不匹配等其他问题，应按提示的具体原因逐项修改。

### 10.5 诊断命令

在普通模式中输入：

```vim
:ALELint
:lopen
:lclose
:ALEInfo
:messages
```

| 命令 | 用途 |
| --- | --- |
| `:ALELint` | 手动请求检查 |
| `:lopen` | 打开当前窗口的问题列表，可选中条目回车跳转 |
| `:lclose` | 关闭问题列表 |
| `:ALEInfo` | 查看当前语言、检查器、执行命令及相关信息 |
| `:messages` | 查看 Vim 已记录的消息和配置错误 |

想立即完整查看当前代码的问题，可以先按 `Esc`，再执行 `:ALELint`。配置默认不强制弹出问题列表，也不在代码右侧铺满行内提示。

### 10.6 多文件 C/C++ 项目

多文件项目可能使用自己的头文件目录、宏定义和不同标准。让检查器读到与实际构建相符的信息，可以减少「明明能编译，编辑器却找不到头文件」的情况。

在 CMake 项目根目录生成编译数据库：

```bash
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
```

生成的 `build/compile_commands.json` 会记录编译选项。仓库自带的 C/C++ 项目模板已经开启这项设置。ALE 按其编译数据库规则读取信息；复杂目录结构仍应通过 `:ALEInfo` 检查实际命令。

默认不通过解析 Makefile 自动调用 `make` 来猜测参数。诊断只检查代码，不运行你的程序；真实链接错误、运行逻辑和内存问题仍需要构建、测试或调试。

<a id="zsh"></a>
## 11. Zsh：提示符、灰色建议与补全

### 11.1 提示符颜色

通常显示为：

```text
peacecdt@tencentcloud:~/study (main) %
```

| 部分 | 默认颜色与行为 |
| --- | --- |
| 普通用户名 | 柔和绿色 |
| root 用户名 | 珊瑚色 |
| `@` | 灰色 |
| 主机名 | 灰蓝色，显示短主机名 |
| 当前路径 | 暖米色，家目录显示为 `~` |
| Git 分支 | 黄色括号；分离 HEAD 时显示短提交号 |
| 最后一个 `%` / `#` | 普通用户为 `%`，root 为 `#`；根据上一条命令成功与否显示绿色或珊瑚色 |

Git 部分显示分支或提交，不额外标记工作区是否有未提交修改。

### 11.2 灰色文字是什么

灰色文字是自动建议，最初还不是你实际输入的命令内容。当前配置通过实时补全产生建议，不直接重放历史里旧的文件名。

- Tab 用于主动补全，可以把文件名补完整后再按 Enter。
- 右方向键可按自动建议插件的行为接受灰字；接受后它就成为实际输入。
- 特定文件命令和简单相对可执行路径支持 Enter 直接接受当前文件名。
- 其他命令的 Enter 只执行已输入内容，不把整个灰色建议自动执行。

提交命令前会清掉没有被接受的灰色文字并重绘，避免执行后屏幕上还留下实际没有执行的字符。

### 11.3 `vim` 后面的文件名

假设当前目录有 `test.c`：

| 当前输入 | 条件 | 按 Enter 的结果 |
| --- | --- | --- |
| `vim tes` | 灰字提示 `t.c` | 打开 `test.c` |
| `vim tes` | 没有灰字，但只有 `test.c` 一个现存前缀匹配 | 打开 `test.c` |
| `vim te` | 没有可接受灰字，且有多个文件匹配 | 进入补全选择，暂不执行 |
| `vim test.c` | 文件名已经完整存在 | 打开原文件，不延伸成其他名称 |
| `vim new.c` | 没有现存匹配 | 正常打开新文件缓冲区 |

你也可以始终先按 Tab，看清完整文件名后再按 Enter。

唯一前缀兜底是针对 `vim <单一路径>` 的处理，`vim -O tes` 等复杂形式不使用这条特殊规则。文件名包含空格、引号等情况，使用 Tab 明确完成输入更合适。

### 11.4 常用文件命令

以下命令支持对当前正在输入的简单文件名接受灰色建议：

```text
vim vi nvim rm gcc g++ cc c++ clang clang++
cat less more head tail wc file cp mv python python3
```

例如：

| 输入 | 灰色部分 | Enter 后实际命令 |
| --- | --- | --- |
| `gcc tes` | `t.c` | `gcc test.c` |
| `gcc -Wall tes` | `t.c` | `gcc -Wall test.c` |
| `python3 tes` | `t.py` | `python3 test.py` |
| `rm tes` | `t.c` | `rm test.c` |

**`rm` 的 Enter 会真正执行删除命令。** 如果希望先确认完整文件名，就先按 Tab，再检查命令后执行。

这些规则只补当前单词，不追加第二个文件参数。`gcc test.c` 的文件名已经完整后，不会再自动接上另一个 `.c` 文件；末尾刚输入空格、还没有输入下一个文件名前缀时，也不会自动替你挑一个文件。

灰色建议在每次显示前都会重新检查路径：删除文件或切换目录后，不会继续使用旧历史中已经不存在的普通文件。符号链接目录项仍可能作为合法目标，例如 `rm` 本来就可以删除一个断开的符号链接。

这些是对列表中命令名的直接匹配，不会递归分析 `sudo vim ...`、`env ... gcc ...` 等包装形式。包含引号、管道、命令替换等复杂表达式时，Enter 保留正常提交行为；可以使用 Tab 明确补全。引号中的文件名仍可能显示灰色建议，不能把「不自动 Enter 接受」理解成「不能补全」。

### 11.5 执行 `./a.out`

如果 `./a.out` 实际存在且有执行权限：

```text
已输入：./a.o
灰色建议：ut
```

可以直接 Enter 执行 `./a.out`，也可以 Tab 补完整后再 Enter。简单的 `../` 相对程序路径也支持这种行为。

程序名已经完整后，不再自动建议 `10.string_cat.c` 等额外文件参数；即使已经开始输入参数，也保持关闭该程序的灰色参数建议。确实需要传参数时，手动输入或按 Tab：

```bash
./a.out input.txt
```

### 11.6 `sudo -i` 和命令选项

以 `-` 开头的当前选项不会被灰色建议自动续写，因此不会把 `sudo -i` 自动提示成 `sudo -iA`。

主动按 Tab 补全选项仍可使用。如果某个字符已经被你输入，或通过 Tab / 右方向键接受成正常文字，它会作为真实命令执行；这与未接受的灰字不同。

### 11.7 历史、fzf 和常用键位

| 操作 | 行为 |
| --- | --- |
| `Tab` | Zsh 补全，支持候选菜单和不区分大小写的匹配 |
| ↑ / ↓ | 按当前输入前缀查找历史命令 |
| Home / End | 移到命令行开头 / 末尾 |
| Delete | 删除光标处字符 |
| `Ctrl+r` | 通常由已加载的 fzf 集成提供模糊历史搜索；未加载时为 Zsh 增量搜索 |
| `Ctrl+t` | 通常由软件包的 fzf 集成提供文件选择 |
| `Alt+c` | 通常由软件包的 fzf 集成提供目录选择 |
| `ll` | `ls -alF --color=auto` |
| `la` | `ls -A --color=auto` |
| `..` | `cd ..` |

Shell 使用 Emacs 风格编辑键位，不是 Vim 模式键位。可以直接输入目录名切换目录，也可以在交互命令中使用 `#` 注释。

历史保存在 `~/.zsh_history`，内存及保存条数均为 20000，增量追加，忽略连续重复命令和以空格开头的命令。这里没有开启多个终端实时共享全部历史的 `share_history`。

旧历史没有被删除，只是不直接拿来生成带过期文件名的灰色建议；仍可通过 ↑ / ↓ 或历史搜索找到它。

fzf 集成来自 APT 软件包，具体默认绑定跟随软件包版本。文件候选使用 `rg --files --hidden`，排除 `.git`、`.venv`、`build`，同时保留 ripgrep 本身的忽略规则。

### 11.8 插件与补全缓存

本配置不需要 Oh My Zsh 或在线插件管理器。自动建议、语法高亮及 fzf 集成来自 Ubuntu 软件包。

补全缓存默认在：

```text
~/.cache/linux-env/zsh/zcompdump-<Zsh版本>
```

设置了有效的绝对 `XDG_CACHE_HOME` 时使用对应缓存根目录。缓存目录、祖先目录和现有缓存文件会检查所有者及写权限；不适合安全保存缓存时，改为不使用磁盘缓存，补全仍可以工作。

<a id="cpp"></a>
## 12. C / C++ 日常学习流程

下面的目录和项目都由你主动执行命令创建，安装器不会替你生成。文件名可自行更换，命令应在对应文件所在目录执行。

### 12.1 单个 C 文件

```bash
mkdir -p ~/study/c
cd ~/study/c
vim hello.c
```

保留模板中的头文件，在其下方编写：

```c
int main(void) {
    printf("Hello, C!\n");
    return 0;
}
```

保存退出后，编译并运行：

```bash
gcc -std=c17 -Wall -Wextra -g hello.c -o hello && ./hello
```

| 参数 | 含义 |
| --- | --- |
| `-std=c17` | 按 C17 标准编译 |
| `-Wall -Wextra` | 开启常用警告 |
| `-g` | 添加调试信息 |
| `-o hello` | 指定输出程序名 |
| `&& ./hello` | 编译成功后才运行程序 |

不使用 `-o` 时，GCC 通常输出 `a.out`。如果编译失败，旧的 `a.out` 可能仍在，使用 `&&` 可以避免失败后误运行旧程序。

只检查语法、不生成程序：

```bash
gcc -std=c17 -Wall -Wextra -fsyntax-only hello.c
```

### 12.2 单个 C++ 文件

```bash
mkdir -p ~/study/cpp
cd ~/study/cpp
vim hello.cpp
```

模板已有常用头文件和 `using namespace std;`，可以在后面添加：

```cpp
int main() {
    cout << "Hello, C++!\n";
    return 0;
}
```

```bash
g++ -std=c++17 -Wall -Wextra -g hello.cpp -o hello && ./hello
```

C++ 程序使用 `g++` 或 `clang++`，不要把 `gcc` 与 `g++` 的链接行为当成完全相同。需要对比 Clang 时：

```bash
clang++ -std=c++17 -Wall -Wextra -g hello.cpp -o hello-clang && ./hello-clang
```

### 12.3 用 GDB 调试

先用 `-g` 编译，再执行：

```bash
gdb ./hello
```

下面的命令是在 **GDB 提示符**中输入：

```text
break main
run
next
step
print 变量名
backtrace
continue
quit
```

`break` 设置断点，`next` 单步且不进入函数，`step` 可以进入函数，`print` 查看表达式，`backtrace` 查看调用栈。`变量名` 应替换成当前作用域内实际存在的变量。

### 12.4 可选：手动创建多文件项目模板

如果只想写单个 `.c` / `.cpp` 文件，可以跳过这一节。需要练习头文件、源文件和测试的组织方式时，再主动运行：

```bash
linux-env-new c ~/study/hello-c
linux-env-new cpp ~/study/hello-cpp
```

`linux-env-new` 支持：

```text
linux-env-new {c|cpp|python} [新项目目录]
```

省略目录时，在当前目录创建 `hello-c`、`hello-cpp` 或 `hello-python`。目标只要已经存在，包括空目录或符号链接，就会拒绝覆盖。该命令仅复制模板与 `.editorconfig`，不会运行程序或自动安装项目依赖。

C/C++ 模板包含：

```text
CMakeLists.txt
include/          函数声明
src/              实现与程序入口
tests/            无需外部测试库的测试
README.md         该模板的说明
.editorconfig
.gitignore
```

以 C++ 为例：

```bash
cd ~/study/hello-cpp
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --output-on-failure
./build/hello_cpp
```

C 模板使用相同步骤，可执行文件是 `./build/hello_c`。

模板采用 C17 / C++17，默认开启常用编译警告并导出编译数据库。修改代码后通常只需重新构建和测试；第一次配置、改变构建选项或切换编译器时再运行相应配置命令。

### 12.5 可选：运行时检查和格式化

在模板项目中开启 AddressSanitizer 与 UBSan：

```bash
cmake -S . -B build-asan -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DLEARNING_ENABLE_SANITIZERS=ON
cmake --build build-asan
ctest --test-dir build-asan --output-on-failure
```

如果当前系统已经安装 Valgrind，可以单独检查普通 Debug 构建：

```bash
valgrind --leak-check=full ./build/hello_cpp
```

需要格式化时，主动指定文件：

```bash
clang-format -style=LLVM -i src/main.cpp
```

这里的 `-i` 会改写指定文件。仓库没有配置自动保存格式化；是否格式化、格式化哪些文件由你决定。

<a id="python"></a>
## 13. Python 日常学习流程

### 13.1 单文件与虚拟环境

```bash
mkdir -p ~/study/python-basic
cd ~/study/python-basic

python3 -m venv .venv
source .venv/bin/activate
vim hello.py
```

在模板注释和导入之后写自己的代码，例如：

```python
print("Hello, Python!")
```

保存后运行：

```bash
python hello.py
```

激活虚拟环境后，`python` 和 `python -m pip` 应指向该环境。可验证：

```bash
command -v python
python -c "import sys; print(sys.executable); print(sys.prefix)"
```

退出虚拟环境：

```bash
deactivate
```

下次进入项目后重新 `source .venv/bin/activate`。也可以不激活，直接使用 `.venv/bin/python hello.py`。

### 13.2 安装项目依赖

激活项目的 `.venv` 后，用该解释器对应的 pip 安装依赖：

```bash
python -m pip install 包名
```

上面的 `包名` 是占位词，需要替换成实际依赖。不要使用 `sudo pip` 向 Ubuntu 系统 Python 中安装项目依赖。

`pytest` 和 `ruff` **不在本仓库默认安装清单中**。如果项目需要，可以在虚拟环境内自行安装：

```bash
python -m pip install pytest ruff
python -m pytest
ruff check .
```

`ruff format .` 会格式化项目文件，需要时再主动运行。默认 Vim 诊断仍使用 APT 的 Flake8，不会因为项目中安装了 Ruff 就自动切换后端。

`pipx` 也已安装，适合按需安装独立的 Python 命令行工具；它与每个项目的 `.venv` 用途不同。

### 13.3 检查语法与调试

```bash
python -m py_compile hello.py
python -m pdb hello.py
```

前者检查已保存文件的语法，可能生成 `__pycache__`，不执行程序；后者进入 Python 调试器。

在 pdb 中可使用 `n` 单步、`s` 进入调用、`p 表达式` 查看值、`c` 继续、`q` 退出。

### 13.4 可选 Python 项目模板

```bash
linux-env-new python ~/study/hello-python
cd ~/study/hello-python
python3 -m venv .venv
source .venv/bin/activate

python -m hello_python
python -m hello_python "Ada Lovelace"
python -m unittest discover -s tests -v
```

示例只使用 Python 标准库，可以直接运行和测试，不必先从 PyPI 安装第三方库。

模板中：

- `hello_python/__init__.py` 放业务函数。
- `hello_python/__main__.py` 提供命令行入口。
- `tests/` 存放标准库 unittest 测试。
- `pyproject.toml` 描述项目打包信息。

想练习把自己的包安装进当前虚拟环境，可以额外执行 `python -m pip install -e .`，之后使用 `hello-python` 命令。这一步可能从 PyPI 获取构建依赖，不是运行示例的必需步骤。

<a id="tmux"></a>
## 14. tmux 会话管理

tmux 可以让一个终端中同时保留多个窗口和分屏，适合远程开发。

### 14.1 创建、离开和返回会话

```bash
tmux new -s study
```

暂时离开会话：**先按 `Ctrl+b`，松开，再按 `d`**。这是分离会话，不是结束里面运行的程序。

在普通 Shell 中查看和返回：

```bash
tmux ls
tmux attach -t study
```

会话在 SSH 断开后能继续存在，前提是 tmux 服务和主机仍在运行。本配置没有系统重启后自动恢复会话或程序的插件。

### 14.2 常用按键

本配置保留默认前缀 `Ctrl+b`。表中的后续键都在按下前缀并松开之后输入，不是三个键一直同时按住。

| 前缀后的键 | 作用 |
| --- | --- |
| `c` | 新窗口 |
| `\|` | 左右分屏 |
| `-` | 上下分屏 |
| `h` / `j` / `k` / `l` | 切换到左 / 下 / 上 / 右窗格 |
| `r` | 重新加载 `~/.tmux.conf` |
| `d` | 分离当前会话，tmux 自带功能 |
| `?` | 查看完整按键列表 |

分屏和新窗口继承当前窗格的工作目录。窗口和窗格从 1 编号，关闭窗口后重排窗口编号。

默认开启鼠标，保留 20000 行滚动历史；复制模式采用 vi 风格键位。状态栏左侧显示会话名，右侧显示日期时间。

个人设置放在 `~/.tmux.conf.local`，更新主配置时不会覆盖这个文件。

<a id="git"></a>
## 15. Git 与 EditorConfig

### 15.1 Git 身份需要自己设置

安装器不会替你设置 Git 提交身份。请在开发账号下执行：

```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

这与 Vim 文件注释中的 `Author`、`Mail` 是两套配置，修改一套不会自动修改另一套。

### 15.2 Git 默认配置

通用设置放在 `~/.config/linux-env/gitconfig`，通过 include 加入个人全局配置。include 插在原个人设置之前，已有的用户名、邮箱、编辑器等设置仍可覆盖这些默认值。

通常使用 `~/.gitconfig`；如果它不存在，但已有 `~/.config/git/config`，安装器会使用后者。

| 默认项 | 含义 |
| --- | --- |
| `core.editor=vim` | 默认编辑器为 Vim；已有个人值优先 |
| `color.ui=auto` | 自动彩色输出 |
| `init.defaultBranch=main` | 以后新建 Git 仓库时默认使用 main，不重命名已有分支 |
| `pull.ff=only` | 拉取只允许快进，分叉时需要你决定合并或变基 |
| `fetch.prune=true` | 清理远端已删除分支对应的远程跟踪引用，不删除普通本地分支 |
| `push.default=simple` | 使用 Git 的 simple 推送策略 |
| `diff.algorithm=histogram` | 使用 histogram 差异算法 |
| `merge.conflictStyle=diff3` | 冲突标记包含共同祖先内容 |
| `core.whitespace` | 识别尾部空格、Tab 前空格等问题，不自动改写文件 |

提供三个简短别名：

```bash
git st       # status -sb
git lg       # 最近20条图形化单行提交记录
git last     # 最后一次提交和文件统计
```

需要确认最终生效值及来源时：

```bash
git config --show-origin --get core.editor
git config --show-origin --get user.name
git config --show-origin --get-all include.path
```

### 15.3 EditorConfig 模板

`~/.config/linux-env/editorconfig` 是一个**模板文件**，不会自动改变所有项目。需要时把它复制为项目根目录的 `.editorconfig`：

```bash
# 先进入目标项目根目录；已有 .editorconfig 时先检查再决定是否替换
cp -i ~/.config/linux-env/editorconfig .editorconfig
```

通过 `linux-env-new` 创建的项目会自动得到该文件。

| 项目 | 默认规则 |
| --- | --- |
| 编码和换行 | UTF-8、LF、文件末尾换行 |
| 普通文件 | 4 个空格缩进，去掉尾部空白 |
| Shell、JSON、YAML、TOML | 2 个空格缩进 |
| Makefile、`*.mk` | Tab 缩进 |
| Markdown | 保留尾部空白，兼容 Markdown 换行用途 |

EditorConfig 需要编辑器或相应插件支持才能执行。仓库没有为 Vim 单独安装 EditorConfig 插件，不能把这个模板理解成所有 Ubuntu Vim 都会自动执行的全局规则；Vim 本身的缩进设置见第 9 章。

<a id="custom"></a>
## 16. 个人定制与配置加载

### 16.1 把长期设置放在哪里

| 个人文件 | 用途 | 更新时是否覆盖 |
| --- | --- | --- |
| `~/.vimrc.local` | Vim 选项、作者邮箱、诊断设置等 | 不覆盖 |
| `~/.zshrc.local` | 个人别名、环境变量、按键等 | 不覆盖 |
| `~/.tmux.conf.local` | tmux 个性化设置 | 不覆盖 |
| 个人 Git 全局配置 | Git 身份和个人选项 | 保留原设置，按需插入一次 include |
| `~/.config/linux-env/vim/` | 自己需要的 Vim runtime 文件 | 不由当前安装器替换 |

以上 `.local` 文件缺失时可以自己创建。请在目标开发账号下编辑；在 root 下编辑 `~/.vimrc.local`，修改的是 root 自己的配置。

主配置 `~/.vimrc`、`~/.zshrc`、`~/.tmux.conf` 属于受管理文件，直接改动会在以后更新时被备份并替换。长期个人习惯放到 `.local` 文件更便于维护。

### 16.2 Vim 自定义示例

```bash
vim ~/.vimrc.local
```

下面的选项按需要选用，不必全部复制：

```vim
" 修改以后新文件模板的署名
let g:linux_env_author = '你的名字'
let g:linux_env_email = 'you@example.com'

" 关闭自动括号和引号配对
" let g:linux_env_auto_pairs = 0

" 关闭横向、纵向定位线
" set nocursorline nocursorcolumn

" 单文件练习需要其他C++标准时，可调整默认检查选项
" let g:ale_cpp_cc_options = '-std=c++20 -Wall -Wextra'

" 完全不需要ALE时，取消下一行的注释，重新打开Vim
" let g:ale_enabled = 0
```

以 `"` 开头的 Vimscript 行是注释。修改署名只影响以后新建文件，不会批量改写旧文件。项目存在编译数据库时，应以项目构建配置为准调整标准、头文件和宏。

### 16.3 旧 Vim 插件与个人插件

当前主配置只加载：

```text
~/.config/linux-env/vim/
/usr/share/vim-ale/          安装了APT插件时
Vim自带runtime
~/.config/linux-env/vim/after/
```

旧的 `~/.vim` 目录保留，但不会作为这套配置的默认插件目录加载，避免归档插件影响新环境。需要个人颜色或 runtime 文件时，使用上述个人目录。

没有配置在线插件管理器，也没有默认安装完整 IDE 插件组合。加入额外语言诊断时，需要自己安装相应检查器，并在 `~/.vimrc.local` 中调整 ALE 语言配置。

### 16.4 Zsh 与 tmux 示例

在 `~/.zshrc.local` 中添加自己的别名，例如：

```zsh
alias cstudy='cd ~/study/c'
alias cppstudy='cd ~/study/cpp'
```

目录应由你自行创建。保存后新开 Zsh，或在当前普通用户会话中执行 `exec zsh`。

Zsh 的个人文件在主要功能和按键之后加载，语法高亮插件最后加载。个人别名、函数或 `bindkey` 可以覆盖原行为，排查冲突时要检查这个文件。

在 `~/.tmux.conf.local` 中，例如关闭鼠标：

```tmux
set -g mouse off
```

随后重新加载 tmux 配置。Git 的个人选项直接通过 `git config --global` 设置即可，不建议直接改写受管理的 include 文件。

<a id="restore"></a>
## 17. 备份、恢复与旧目录处理

### 17.1 用户配置备份

需要替换已有配置时，备份保存在目标账号自己的目录中：

```text
~/.local/state/linux-env/backups/<年月日-时分秒>-<进程号>/
```

例如：

```text
~/.local/state/linux-env/backups/20261016-100000-12345/
├── .vimrc
├── .zshrc
├── .tmux.conf
├── .gitconfig
└── .config/
    └── linux-env/
        └── gitconfig
```

上面只是可能的布局，**每次备份只包含当次被更改文件的旧版，不是整个 home 的完整快照**。某个备份目录中没有 `.vimrc`，可能只是那次没有替换它，不能据此判断所有历史备份都没有它。

具体行为：

- 原配置与新配置相同的普通文件，不重复备份。
- 配置原本不存在，不会为它制造一个空的旧版本。
- 原目标是符号链接时，备份链接本身，再部署新的普通文件。
- Git 全局文件在首次添加 include 前会保留一份副本。
- 没有需要备份的文件时，`backups/` 可能尚未创建，这是正常的。
- 你的项目源码和 `~/.ssh` 不属于这套配置备份的内容。

### 17.2 查看有什么备份

在开发账号下执行：

```bash
ls -la ~/.local/state/linux-env

if [[ -d "$HOME/.local/state/linux-env/backups" ]]; then
    find "$HOME/.local/state/linux-env/backups" -mindepth 1 -print
fi
```

根据时间和实际包含的文件选择需要恢复的目录。不要简单把「最新一个目录」当成完整恢复点，也不要把所有备份文件整体覆盖回主目录。

### 17.3 按文件恢复示例

下面以恢复 `.vimrc` 为例。先把示例目录名替换为实际备份目录，再在**目标普通用户**的 Bash 或 Zsh 中执行：

```bash
(
set -e
restore_backup="$HOME/.local/state/linux-env/backups/填写实际的备份目录名"

if [[ -f "$restore_backup/.vimrc" || -L "$restore_backup/.vimrc" ]]; then
    restore_current=$(mktemp -d "$HOME/linux-env-before-restore.XXXXXXXX")
    if [[ -e "$HOME/.vimrc" || -L "$HOME/.vimrc" ]]; then
        mv -- "$HOME/.vimrc" "$restore_current/.vimrc"
    fi
    cp -a -- "$restore_backup/.vimrc" "$HOME/.vimrc"
    printf '已恢复 .vimrc；恢复前的版本位于：%s\n' "$restore_current"
else
    printf '该备份中没有 .vimrc，请重新选择包含它的备份目录。\n'
fi
)
```

这会先把当前文件另存到一个新的目录，再复制指定旧版本，保留原备份。外层括号让恢复操作在子 Shell 中执行，创建目录或移动文件失败时会停止，不退出你的交互终端。恢复 `.zshrc`、`.tmux.conf` 时按同样方式逐个处理；重新打开相应程序后生效。

Git 全局配置也应按实际原路径恢复，可能是 `~/.gitconfig`，也可能是 `~/.config/git/config`。如果只是取消本项目的 Git 默认值，可以编辑实际全局文件，移除引用 `~/.config/linux-env/gitconfig` 的那一项 include，保留其他 include 和自己的身份配置。

### 17.4 登录 Shell 需要单独恢复

恢复 `.zshrc` 不会把账号登录 Shell 改回 Bash。确实需要改回时，在该普通账号下执行：

```bash
chsh -s /bin/bash
```

之后重新登录。已打开的 Zsh 不会因登录 Shell 改变而立即消失；暂时使用 Bash 也可以直接运行 `bash`。

### 17.5 主机名备份与恢复

主机名相关备份由 root 保存在另一个位置：

```text
/var/backups/linux-env/hostname-<时间>.<随机字符>/
```

| 备份内文件 | 对应原位置 |
| --- | --- |
| `hostname` | `/etc/hostname`，原先存在时备份 |
| `hosts` | `/etc/hosts` |
| `cloud-hostname.cfg` | 原先已有的 `/etc/cloud/cloud.cfg.d/99-linux-env-hostname.cfg` |

需要恢复时，先检查备份内容，再分别处理运行中的主机名、`/etc/hostname`、`/etc/hosts` 和 cloud-init 的配置。只复制 `/etc/hostname` 不会立即改变当前内核中的主机名。

如果备份中存在 `cloud-hostname.cfg`，它对应原来的同名 cloud-init 配置；如果不存在，说明此次没有备份该原文件，不能把它当成一份空配置直接覆盖。是否移除本次新建的 cloud-init 文件，应按你希望继续保留自定义主机名，还是交回 cloud-init 管理来决定。

脚本没有通用的一键系统回滚命令。恢复用户配置不会自动撤销软件包安装、账号创建、sudo 组成员、公共工具部署或主机名修改。

### 17.6 旧目录哪些可以保留

**试用新版前不需要先删旧目录。**

| 目录或文件 | 当前配置如何处理 |
| --- | --- |
| `~/.ssh` | 不修改；保留你的登录密钥和授权信息 |
| `~/c`、`~/c-plus-plus`、`~/datastructure`、`~/linux` 等代码目录 | 不删除、不移动、不自动生成新项目覆盖 |
| `~/.vim` | 可保留，当前 Vim 主配置不默认加载其中插件 |
| `~/.oh-my-zsh` | 可保留，当前 Zsh 配置不使用 Oh My Zsh |
| `.linux-env-backup-*` 等旧备份 | 可继续保留，确认无需恢复后再自行整理 |
| `~/linux-env` 仓库克隆 | 是你的源码工作区，安装器不会要求先删除它 |
| `~/.cache`、`~/.local` | 可能包含其他软件数据，不应把整个目录当成本项目的垃圾目录 |
| `.zsh_history`、`.viminfo` | 属于你的使用历史，不需要为了更新环境而删除 |

如果是还原旧版环境，旧 `.vimrc` 可能会重新加载旧 `~/.vim` 插件；这与新版的加载策略不同，排查时要结合自己恢复的配置判断。

<a id="troubleshooting"></a>
## 18. 常见问题与排查

### 18.1 下载失败，或者一直没出现安装向导

先区分错误发生在哪里：

1. `wget` 失败：检查当前平台的文件下载域名、DNS 和网络；Gitee 可以尝试第 3 章的同平台备用地址。
2. 提示获取仓库后 `git fetch` 失败：检查当前平台的 Git HTTPS 地址是否可达。入口文件能下载，不代表 Git 仓库协议路径也能访问。
3. APT 失败：检查 Ubuntu 软件源和包管理状态，与 Git 平台下载源分开处理。
4. 没有向导但开始安装：可能检测为无交互终端，或传了 `--non-interactive`。

需要在终端中强制打开向导：

```bash
bash init_env.sh --interactive
```

如果没有可用控制终端，此参数会明确报错，不会凭空提供一个密码输入界面。

### 18.2 去哪里看安装日志

```bash
sudo ls -lt /var/log/linux-env
```

选定具体日志后查看，例如：

```bash
sudo less /var/log/linux-env/填写实际的日志文件名
```

脚本会打印本次日志的完整位置。日志从正式安装器中段开始，入口的 Git 获取、前置 APT 准备和早期参数错误可能只显示在终端；向导提示与密码输入直接使用控制终端，也不写入该日志。

### 18.3 提示已有安装正在运行，或 APT 被占用

本项目的安装锁与系统 APT 锁是两回事。先确认是否另一个安装器或系统更新正在运行，等待它正常结束后重试。安装器的 APT 命令设置了最长 180 秒的锁等待，但不会强制终止正在运行的其他包管理进程。

如果先前 APT 被中断，可以在 root 终端按系统报错提示修复，例如：

```bash
dpkg --configure -a
apt --fix-broken install
```

完成后重新运行安装器。不要把删除锁文件当成结束包管理进程的办法。

### 18.4 更新后颜色、补全或按键还是旧的

依次确认：

```bash
whoami
ps -p $$ -o comm=
getent passwd "$(whoami)"
```

然后：

- 确认安装时选中的是当前开发账号，而不是 root 或另一个账号。
- 如果当前仍是旧 Zsh 会话，执行 `exec zsh`，或重新登录。
- Vim 保存退出后重新打开。
- 查看 `.zshrc.local`、`.vimrc.local` 是否覆盖了默认行为。
- 重新下载入口后必须再次执行安装；仅下载不会更新配置。

### 18.5 文件已经删了，灰色建议仍像以前一样

新版常用文件命令建议不使用历史中的旧文件名。若仍发生：

1. 确认已经安装最新版，并重新进入 Zsh。
2. 确认当前目录中确实没有同名文件、目录或符号链接，可用 `ls -la` 查看。
3. 检查 `~/.zshrc.local` 是否重新加载 Oh My Zsh、其他自动建议配置，或把策略改回历史建议。
4. 用 `bindkey '^M'` 查看 Enter 是否仍绑定为 `_linux_env_accept_line`。

通过 ↑ / ↓ 或 `Ctrl+r` 找到旧历史命令是正常的，历史搜索与灰色自动建议不是同一个功能。

### 18.6 Enter 没有接受灰色文件名

检查是否属于第 11 章支持的情况：

- 当前命令是否在常用文件命令列表中。
- 是否是简单字面路径，是否包含引号、空格文件名、管道等复杂表达式。
- 是否被 `sudo`、`env` 等包装。
- 相对程序是否实际存在且可执行。
- `vim` 的前缀是否有多个匹配；多个匹配可能进入选择而不是直接执行。

这些情况下可以使用 Tab 明确补全。Tab 和 Enter 的规则有意不同，不是所有能显示灰字的命令都会被 Enter 自动接受。

### 18.7 `sudo -i` 后面又出现 `A` 等字符

新版会阻止灰色自动续写命令选项，并在执行前清除未接受灰字。先重新进入 Zsh，检查是否仍加载旧配置或其他按键设置。

如果字符已经被自己输入或被 Tab / 右方向键接受，它就属于真正的命令内容。不能仅凭颜色截图认定 Shell 忽略了它；执行前检查实际输入即可。

### 18.8 Vim 没有自动文件头

- 文件是否早就存在，包括一个已经存在的空文件。
- 扩展名是否是小写 `.c`、`.cpp`、`.cc`、`.cxx` 或 `.py`。
- 当前是否使用目标开发账号的 Vim 配置。
- 个人配置是否清除了相关自动命令。

在 Vim 中检查：

```vim
:echo $HOME
:echo $MYVIMRC
:scriptnames
```

现有文件不补模板是为了保留原内容；无需删除自己的源码来触发模板。

### 18.9 Vim 不配对括号或引号

```vim
:set paste?
:echo g:linux_env_auto_pairs
:verbose imap (
```

若处于粘贴模式，执行 `:set nopaste`。若 `g:linux_env_auto_pairs` 为 `0`，检查自己的 `.vimrc.local`。`:verbose imap (` 会显示当前左括号映射及它的定义来源，可据此查找个人插件冲突。

### 18.10 Vim 没有错误提示，或不认识 `:ALELint`

先在开发账号下运行：

```bash
linux-env-doctor
ls -l /usr/share/vim-ale/plugin/ale.vim
command -v clang clang++ flake8
```

再在 Vim 中查看：

```vim
:echo &filetype
:ALEInfo
:messages
```

默认文件类型应为 `c`、`cpp` 或 `python`。缺少 ALE 或检查器时，重新下载入口，并**不带 `--skip-packages`**更新安装，之后重开 Vim。个人设置中的 `let g:ale_enabled = 0` 也会关闭诊断。

其他语言没有自动诊断，不等于安装失败；需要单独接入对应检查器。

### 18.11 为什么刚写的新行没提示，或者旧错误暂时还在

先按第 10 章的更新规则判断：

- 新行首次输入时，故意先不显示新问题，离开该行后检查。
- 已有错误不会因为在其他行输入空格就全部清掉。
- 修正后要等待约 0.4 秒的输入暂停以及检查器执行时间。
- 未写完的其他语句可能让编译器停止分析，配置会先保留已确认结果。
- 若想立即完整检查，按 `Esc`，执行 `:ALELint`，再用 `:lopen` 看具体问题。

`unused variable`、`uninitialized`、`undeclared identifier` 是不同的问题。初始化一个变量不会自动消除「未使用」警告或另一个名字的「未声明」错误。

### 18.12 为什么底部没有 `-- INSERT --`，只有错误原因

错误说明与模式提示使用同一消息区域。当前行有诊断时会暂时让错误原因占用该区域，实际仍能保持 INSERT 输入。移到没有诊断的行、清除提示或按 `Esc` 后会相应更新。

### 18.13 C/C++ 头文件找不到，或者 `空格 b` 构建失败

头文件问题先检查项目是否生成 `compile_commands.json`，其中是否包含实际的 `-I` 路径和宏定义，再通过 `:ALEInfo` 对照检查器命令。

`空格 b` 等于 `:make`，默认 C/C++ 执行 `cmake --build build`：

- 要先保存源码。
- 需要项目有 `CMakeLists.txt`，且已生成 `build`。
- Vim 当前工作目录要适合这个构建命令，可以用 `:pwd` 查看。
- 单个独立 `.c` 文件通常直接在终端用 GCC 编译，不需要强行使用 CMake。

查看构建错误用 `:copen`；查看 ALE 编辑诊断用 `:lopen`。

### 18.14 Python 提示系统环境受管理，或者虚拟环境不对

先进入项目并创建、激活 `.venv`：

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip --version
```

使用虚拟环境中的 `python -m pip` 安装依赖，不需要通过破坏系统 Python 的方式绕过提示。

Vim 的 Python `:make` 会优先寻找文件路径上最近的 `.venv`；ALE 默认使用系统 Flake8。这两者的解释器选择不同，不要只根据 Flake8 的路径判断项目运行解释器是否正确。

### 18.15 没有 fzf 历史搜索或文件选择

```bash
command -v fzf
zsh -ic 'bindkey "^R"; bindkey "^T"'
ls -l /usr/local/share/linux-env/fzf
```

极简云镜像可能剥离 APT 包中的 `/usr/share/doc` 文件，安装器会补装并保存 fzf 集成脚本的备用副本。缺少集成时，先不带 `--skip-packages` 更新，再进入新 Zsh 会话。

### 18.16 tmux 显示与普通 SSH 终端不同

分别在 tmux 内外检查 `echo "$TERM"`，并确认终端支持 256 色和下划线。tmux 配置默认使用 `screen-256color`；如果问题只在旧 tmux 会话中出现，先重新加载配置或创建新会话验证。

### 18.17 Git 拉取提示不能快进

本配置默认 `pull.ff=only`。当本地与远端都出现新提交时，Git 会要求你明确决定合并还是变基，不是仓库损坏。

先用 `git st` 和 `git lg` 查看状态与提交，按自己的分支管理方式处理。不要为了绕过提示直接覆盖远端或删除本地未保存工作。

<a id="maintenance"></a>
## 19. 仓库结构、测试与双平台维护

### 19.1 仓库结构

```text
linux-env/
├── init_env.sh                  可单独下载的安装入口
├── README.md                    本文档
├── config/
│   ├── vimrc                    Vim、模板、配对与代码诊断
│   ├── zshrc                    提示符、实时建议和按键
│   ├── tmux.conf                tmux 配置
│   ├── gitconfig                Git 通用默认值
│   └── editorconfig             项目 EditorConfig 模板
├── scripts/
│   ├── install.sh               系统安装与目标账号部署
│   ├── identity.sh              交互式主机名、账号和密码设置
│   ├── configure-home.sh        以目标用户权限更新个人文件
│   ├── linux-env-doctor         基础环境自检
│   ├── linux-env-new            可选项目模板复制
│   ├── collect_teacher_config.sh 历史配置采集工具
│   └── audit_payload.sh         历史 payload 审查工具
├── examples/
│   ├── c/                       C17 多文件模板
│   ├── cpp/                     C++17 多文件模板
│   └── python/                  Python 包与 unittest 模板
├── tests/                       自动化验证
├── .github/workflows/ubuntu.yml  GitHub Actions 工作流
├── archive/legacy/              历史安装脚本归档
├── payload/                     旧配置内容
└── notes/                       历史来源说明等记录
```

当前入口不执行 `collect_teacher_config.sh`、`audit_payload.sh` 或归档中的旧安装脚本。它们不属于正常安装步骤，也不需要为了安装本环境手动运行。

### 19.2 自动验证覆盖什么

工作流位于 [`.github/workflows/ubuntu.yml`](.github/workflows/ubuntu.yml)，在 GitHub 上的 push、pull request 或手动触发时运行。

| 文件 | 主要验证内容 |
| --- | --- |
| [`tests/lint.sh`](tests/lint.sh) | 当前维护的 Bash 脚本语法、LF 换行与 ShellCheck；排除保留的旧采集和审查脚本 |
| [`tests/integration.sh`](tests/integration.sh) | 容器内完整安装、重复安装、文件所有权、个人设置保留、显式 root 配置、自检和项目运行 |
| [`tests/bootstrap.sh`](tests/bootstrap.sh) | 独立入口、两平台默认值、来源优先级、固定提交、部分获取与稀疏检出 |
| [`tests/identity.py`](tests/identity.py) | 实际终端中的身份向导、主机名规则、账号和密码相关行为 |
| [`tests/editor.py`](tests/editor.py) | 新文件模板、已有文件保护、真实 Tab/Enter 与实时建议 |
| [`tests/vim-pairs.vim`](tests/vim-pairs.vim) | 实际映射的括号、引号、退格、换行、粘贴及定位线 |
| [`tests/sudo-suggestions.py`](tests/sudo-suggestions.py) | sudo 参数、Tab、灰字接受和提交后真实终端显示 |
| [`tests/diagnostics.py`](tests/diagnostics.py) | Clang / Flake8 实际诊断、标记、保存和退出 INSERT 更新、未保存修正及编译数据库 |
| [`tests/diagnostics-edit.py`](tests/diagnostics-edit.py) | 实际 INSERT 输入、其他行编辑时保留错误、行号移动、同一行修正、底部说明和旧检查取消 |

完整安装测试分别在 Ubuntu 22.04、24.04、26.04 容器内执行。默认只修改 README 也可能触发 GitHub 工作流；是否通过应查看具体提交的结果，不把以前的一次成功当成所有以后版本的保证。

查看 [GitHub Actions 运行记录](https://github.com/peacecdt/linux-env/actions)。Gitee 共享这些配置与测试文件，但 GitHub Actions 工作流不会因为文件同步到 Gitee 就自动在 Gitee 上执行。

### 19.3 在本地检查仓库

仅做 Bash 静态检查，可在装有 Bash、ShellCheck 的环境中执行：

```bash
bash tests/lint.sh
```

完整集成测试会安装软件包并创建测试账号，应该在**可丢弃的 Ubuntu 容器**中运行，不要当成普通自检命令在日常云主机上执行。

已装好 Docker 的 Linux 开发环境中，例如：

```bash
docker run --rm \
  --mount "type=bind,source=$PWD,target=/repo,readonly" \
  --workdir /repo \
  ubuntu:24.04 bash tests/integration.sh
```

在仓库根目录执行，替换镜像标签可验证另外两个支持版本。该示例是开发者测试方式，安装器不要求你先安装 Docker；日常验证使用 `linux-env-doctor`。

### 19.4 同步 GitHub 和 Gitee 时保留什么

- `config/`、当前安装脚本、示例、测试和 README 保持一致。
- GitHub 的 `init_env.sh` 保留 `DEFAULT_SOURCE=github`。
- Gitee 的 `init_env.sh` 保留 `DEFAULT_SOURCE=gitee`。
- 不把源平台的入口逐字覆盖到另一平台，导致默认下载源被改错。
- 不用两个仓库的提交 SHA 是否相同判断同步成功，而要比较实际配置内容及这一处预期差异。
- 两端都有共享祖先提交时，也仍需保留各自的平台默认值，不能直接无条件镜像整个分支。

修改后核对 README 的功能描述、命令参数和安装路径，再按改动范围运行相关验证。涉及代码诊断、补全或交互按键的改动，除了静态检查，还应覆盖真实终端行为。
