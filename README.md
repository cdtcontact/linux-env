# linux-env

面向 C/C++ 和 Python 学习的 Ubuntu 一键开发环境。保留旧配置中的 Vim、Zsh、tmux 使用习惯，采用 Ubuntu 软件源中的工具和插件，减少过时插件、二进制文件和外部安装脚本带来的依赖。

支持 Ubuntu **22.04 / 24.04 / 26.04 LTS**。需要网络和 root 权限；适用于终端、服务器、虚拟机和 Ubuntu WSL 环境。

## 一键安装

先在 Ubuntu 中准备依赖（两种方式相同）：

```bash
sudo -i

apt update
apt upgrade -y
apt autoremove -y
apt install wget ca-certificates -y
```

**GitHub 仓库安装**：入口和后续配置均从 GitHub 下载。

```bash
wget -O init_env.sh https://raw.githubusercontent.com/cdtcontact/linux-env/main/init_env.sh
bash init_env.sh
```

**Gitee 仓库安装**：入口和后续配置均从 Gitee 下载。

```bash
wget -O init_env.sh https://raw.giteeusercontent.com/peacecdt/linux-env/raw/main/init_env.sh
bash init_env.sh
```

Gitee 文件地址如无法访问，可换用同平台的备用入口：

```bash
wget -O init_env.sh https://gitee.com/peacecdt/linux-env/raw/main/init_env.sh
bash init_env.sh
```

下载哪个平台的入口，就默认使用该平台获取后续配置，直接 `bash init_env.sh` 即可，无需额外参数。两个仓库的工具配置保持一致，各自入口的默认平台不同，也不会自动切换到另一平台。安装器使用公开 HTTPS，不需要 Git 平台账号或 SSH 密钥；软件包仍从机器现有的 Ubuntu APT 源安装，不自动更换系统软件源或 pip 镜像。

安装器默认配置有效的 `SUDO_USER` 对应账号；没有该变量时配置 root。通过 `sudo -i` 进入 root 后，如需确保配置到已有普通用户，请明确指定用户名，例如：

```bash
bash init_env.sh --user alice
```

`alice` 需替换为你的已有用户名。安装完成后，以目标用户重新登录以启用 Zsh；也可以先在该用户终端执行 `exec zsh`。

安装器会更新 APT 索引并安装所需软件包，**不会执行系统升级或自动清理**；上面的 `apt upgrade` 和 `apt autoremove` 由你决定是否运行。脚本不创建用户，不修改密码、SSH、sudo 权限或主机名。

## 安装内容

| 用途 | 工具与配置 |
| --- | --- |
| C/C++ | GCC/G++、Clang、CMake、Ninja、GDB、pkg-config、clangd、clang-format、clang-tidy；仓库提供 Valgrind 时一并安装 |
| Python | Python 3、开发头文件、pip、venv、pipx；每个项目独立使用虚拟环境 |
| 编辑与终端 | Vim、Zsh、tmux、Git、ripgrep、fzf、Universal Ctags、ShellCheck |
| Zsh 插件 | Ubuntu 软件源中的自动建议和语法高亮 |
| 学习起点 | C/C++ 的 CMake 项目和测试，以及 Python 标准库 unittest 示例 |

Python 环境不向系统 Python 全局安装第三方包。`pytest`、`ruff` 等工具可按项目需要安装；基础示例与安装自检无需访问 PyPI。

默认把目标账号的登录 Shell 设为 Zsh；使用 `--no-change-shell` 可保留原登录 Shell。

## 从示例开始学习

以下命令在**目标用户自己的终端**运行。`linux-env-new` 复制模板到新目录，已有目录不会被覆盖：

```bash
linux-env-new c ~/code/hello-c
linux-env-new cpp ~/code/hello-cpp
linux-env-new python ~/code/hello-python
```

C/C++：

```bash
cd ~/code/hello-cpp
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --output-on-failure
./build/hello_cpp
# 调试：gdb ./build/hello_cpp
```

C 模板使用相同构建步骤，可执行文件为 `./build/hello_c`。在 GDB 中用 `break main`、`run`、`next`、`print` 观察程序执行与变量。

Python：

```bash
cd ~/code/hello-python
python3 -m venv .venv
source .venv/bin/activate
python -m hello_python
python -m unittest discover -s tests -v

# 按需安装项目开发工具
python -m pip install pytest ruff
# 离开虚拟环境
deactivate
```

完整示例保存在 `~/code/linux-env-examples`，可反复复制练习。运行 `linux-env-doctor` 可重新检查 C/C++ 编译、Python 虚拟环境与配置文件；首次安装默认执行该检查。

## 配置、自定义与备份

| 位置 | 作用 |
| --- | --- |
| `~/.vimrc` | Vim 基础设置；个人设置放入 `~/.vimrc.local` |
| `~/.zshrc` | Zsh、补全、历史与插件；个人设置放入 `~/.zshrc.local` |
| `~/.tmux.conf` | tmux 快捷键与终端设置；个人设置放入 `~/.tmux.conf.local` |
| `~/.config/linux-env/gitconfig` | Git 通用设置，通过 include 引用，保留已有用户名和邮箱 |
| `~/.config/linux-env/editorconfig` | 可复制到项目根目录的 `.editorconfig` 模板 |
| `~/.local/state/linux-env/backups/<时间戳>/` | 替换已有文件前保存的备份 |

可以重复执行安装脚本，更新这套受管理的配置。三个 `.local` 文件用于保存你的长期定制，不会被安装器覆盖。需要恢复时，从对应时间戳目录取回文件；登录 Shell 需另行用 `chsh` 改回。

Git 提交身份由你自行设置，例如：

```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

## 参数与版本选择

```bash
bash init_env.sh --help
bash init_env.sh --user alice --no-change-shell

# 仅在依赖已安装的机器上使用；缺少依赖时会报错
bash init_env.sh --user alice --skip-packages

# 明确需要时跳过安装后的自检
bash init_env.sh --user alice --skip-checks
```

默认从入口所属仓库（[GitHub](https://github.com/cdtcontact/linux-env) 或 [Gitee](https://gitee.com/peacecdt/linux-env)）的 `main` 下载配置；需要时可手动切换平台、固定版本或使用自己的 fork：

```bash
# 显式选择下载源
bash init_env.sh --source gitee
bash init_env.sh --source github

# 用环境变量选择；--source 参数会覆盖此变量
LINUX_ENV_SOURCE=github bash init_env.sh

# 默认 main，也可指定分支、标签或提交 SHA
LINUX_ENV_REF="<分支、标签或提交>" bash init_env.sh

# 自定义仓库 URL 优先级最高，覆盖 --source 和 LINUX_ENV_SOURCE 的仓库选择
LINUX_ENV_REPO_URL=https://gitee.com/你的账号/linux-env.git bash init_env.sh
```

不设置 `LINUX_ENV_SOURCE` 时，GitHub 入口默认 `github`，Gitee 入口默认 `gitee`。该变量和命令行 `--source` 只接受 `gitee` 或 `github`；命令行优先于环境变量。自定义仓库仍使用 `LINUX_ENV_REF` 指定版本。

固定版本时，请同时从该版本下载 `init_env.sh`，再将 `LINUX_ENV_REF` 设为同一版本。已克隆仓库可直接运行根目录的 `bash init_env.sh`，使用本地配置。

## 仓库结构

- `init_env.sh`：可单独下载的入口；按需取得 `config/`、`scripts/`、`examples/`。
- `config/`：当前维护的终端与编辑器配置。
- `scripts/`：安装、自检与项目模板命令；旧配置收集脚本仍保留供追溯。
- `examples/`：C、C++、Python 学习模板。
- `archive/legacy/`、旧 `payload/`：历史配置归档，其中保留的上游 GitHub 链接不属于当前安装的网络依赖；安装流程不执行、不部署，也不下载其大型插件内容。
- `.github/`：GitHub Actions 持续集成配置，安装器不使用。

两端共享安装与开发配置；同步更新时，`init_env.sh` 顶部的 `DEFAULT_SOURCE` 在 GitHub 保持 `github`，在 Gitee 保持 `gitee`。自动测试会分别验证这两种入口的默认行为。

网络或 APT 操作失败后，可修复网络或软件源并重跑同一命令。系统包和插件的版本跟随 Ubuntu 软件源；脚本声明支持的系统版本不代表所有版本都已完成真实机器验证。
