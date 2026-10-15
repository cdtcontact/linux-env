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
wget -O init_env.sh https://raw.githubusercontent.com/peacecdt/linux-env/main/init_env.sh
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

在交互终端中执行 `bash init_env.sh`，安装器会依次引导你完成：

1. **主机名**：输入 1–63 个纯英文字母，例如 `myubuntu`；大写会转为小写，直接回车保留原主机名。
2. **开发用户名**：可以选已有账号，也可以输入新用户名。直接回车使用有效的 `SUDO_USER` 对应账号，没有该变量时使用 root。新普通用户名需以小写英文字母开头，只含小写字母、数字、`_` 和 `-`，最多 32 个字符。
3. **账号密码**：新用户会创建主目录，通过系统 `passwd` 命令设置密码，成功后再加入 sudo 组。已有用户会先询问是否修改密码，默认不修改。密码需隐藏输入两遍，不通过命令行参数传递，也不写入安装日志。

安装器会给选中的账号配置开发环境。已有账号不会被删除或重建，原有 sudo 权限保持不变。通过 `sudo -i` 进入 root 后，也可指定一个已有用户名作为向导的默认选择，例如：

```bash
bash init_env.sh --user alice
```

`alice` 需替换为你的已有用户名。安装完成后，以目标用户重新登录以启用 Zsh；也可以先在该用户终端执行 `exec zsh`。如果创建了新账号，请保留当前登录会话，另开终端确认新账号可以登录。

修改主机名时，安装器会先备份 `/etc/hostname` 和 `/etc/hosts`；检测到 cloud-init 时，会在独立配置文件中设置 `preserve_hostname: true` 和 `manage_etc_hosts: false`，保留自定义主机名及本机解析。已有同名 cloud-init 配置也会备份。脚本不更改 SSH 服务的密码登录策略；设置了账号密码，并不代表云平台和 SSH 服务已允许用密码远程登录。

安装器会更新 APT 索引并安装所需软件包，**不会执行系统升级或自动清理**；上面的 `apt upgrade` 和 `apt autoremove` 由你决定是否运行。

已有环境无需重装 Ubuntu。按上面的 GitHub 或 Gitee 地址重新下载对应平台的入口后，在 root 终端更新即可；这次新增的 Vim 代码诊断需要安装 `vim-ale` 和 `flake8`，请不要加 `--skip-packages`：

```bash
bash init_env.sh --non-interactive --user peacecdt
su - peacecdt
```

`peacecdt` 替换为实际使用的开发用户名。这会保留主机名和密码，更新前自动备份旧配置；不删除学习项目。依赖全部安装后，以后只更新配置时可以追加 `--skip-packages`。必须进入新的 Zsh 会话（上面的 `su -` 或重新登录）才能加载终端补全修复，Vim 配置在重新打开 Vim 后生效。仅下载入口或在已有终端继续输入命令，不会重新加载配置。

## 安装内容

| 用途 | 工具与配置 |
| --- | --- |
| C/C++ | GCC/G++、Clang、CMake、Ninja、GDB、pkg-config、clangd、clang-format、clang-tidy；仓库提供 Valgrind 时一并安装 |
| Python | Python 3、开发头文件、pip、venv、pipx、Flake8；每个项目独立使用虚拟环境 |
| 编辑与终端 | Vim、ALE 代码诊断、Zsh、tmux、Git、ripgrep、fzf、Universal Ctags、ShellCheck |
| Zsh 插件 | Ubuntu 软件源中的自动建议和语法高亮 |
| 新文件模板 | 手动用 Vim 新建 C/C++、Python 文件时插入署名、时间和常用头文件/导入 |

Python 工具和 Flake8 由 APT 管理，不使用 `sudo pip` 向系统 Python 安装第三方包。`pytest`、`ruff` 等工具可按项目需要在虚拟环境中安装；安装自检无需访问 PyPI。

默认把目标账号的登录 Shell 设为 Zsh；使用 `--no-change-shell` 可保留原登录 Shell。

## 文件编辑与可选示例

安装只配置工具和编辑器，**不会自动创建 C/C++/Python 项目或 `~/code` 目录**，也不会移动或覆盖已有项目。

手动运行 `vim test.c`、`vim test.cpp`、`vim test.py` 新建文件时，会在缓冲区插入文件名、作者 `chendatao`、邮箱 `peacecdt@gmail.com`、创建时间及常用头文件或标准库导入；保存后才写入磁盘，已有文件不会改写。

Vim 在所有文件类型的插入模式下自动配对 `()`、`[]`、`{}`、双引号、单引号和反引号，光标留在中间；再次输入紧邻光标的右括号或闭引号会跳过已有字符。在空配对中按退格会同时删除两边，在空括号中按 Enter 会展开并缩进。支持转义引号和 Python 三引号；`:set paste` 粘贴模式保留原文。需要关闭时，可在 `~/.vimrc.local` 加入 `let g:linux_env_auto_pairs = 0`。

Vim 默认显示随光标移动的十字定位线：横向为当前行底部的一条细下划线，纵向为柔和的灰色背景列，保留代码语法颜色；深色、浅色背景均可使用。临时隐藏可执行 `:set nocursorline nocursorcolumn`。

Vim 使用 Ubuntu 软件源中的 ALE 提供代码诊断。C/C++ 由 Clang / Clang++ 检查，Python 由 Flake8 检查；打开、保存文件或退出插入模式后自动更新，检查不会运行你的程序或自动修改代码。左侧 `>>` 表示错误、`!!` 表示警告，问题范围以下划线标出；光标停在问题行时，底部显示具体信息。可用 `:ALELint` 手动检查、`:lopen` 打开问题列表、`]d` / `[d` 跳转到下一个 / 上一个问题。其他语言需另行安装对应检查器，并在 `~/.vimrc.local` 中配置 ALE。

输入过程中暂时隐藏正在修改、尚未结束编辑的那一行诊断。修改代码时立即清除上一版本的整份文件诊断并取消旧检查，避免声明、初始化等修改后其他行仍显示过期错误；换到其他行后再检查新内容，插入模式下按方向键或 Enter 换行也会触发，不必先保存或退出 INSERT。检查后返回问题行，只移动光标、不修改代码时，会保留标记和下划线，并在底部显示原因，和普通模式一样；真正继续修改后才清除过期提示。同一行持续输入不会反复检查，保存或退出 INSERT 也会重新检查。

Python 默认仅检查 `E9,F63,F7,F82`（语法错误、部分易错表达式和未定义名字等），减少缩进宽度、行长之类风格提示。Flake8 使用 APT 版本做静态检查，不导入项目模块；项目依赖仍安装在各自的虚拟环境中。C/C++ 多文件项目按 ALE 的标准方式读取编译数据库；可用 `cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` 生成 `build/compile_commands.json`，让检查器使用项目的头文件路径、宏和编译选项。诊断结果不能代替完整构建或运行测试。

Zsh 用户名为柔和绿色（root 为珊瑚色），主机名为灰蓝色，路径为暖米色。保留灰色自动建议与 Tab 补全：`vim tes` 若有可用的完整文件建议，Enter 可直接打开该文件；没有灰色建议时，唯一前缀匹配也可直接打开，多个匹配则进入补全选择。

输入 `./a.o` 并显示灰色的 `ut` 时，Enter 可直接执行 `./a.out`；也可以先按 Tab 补全，再按 Enter。该行为同样支持 `../` 开头的简单相对程序路径，只接受实际存在且可执行的完整文件名。程序名已完整时（包括后面已经输入空格或参数），不再自动建议 `10.string_cat.c` 之类的参数文件；需要参数时仍可手动输入或按 Tab 补全。文件参数已完整时，例如 `gcc test.c`，也不再追加灰色文件建议。

`rm`、`gcc`、`g++`、`cat`、`cp`、`mv`、`python3` 等常用文件命令也支持 Enter 接受当前显示的现存文件名，例如 `rm te` 显示灰色 `st.c` 时，Enter 会执行 `rm test.c`。只补正在输入的这个文件名，不追加下一个参数；空格后没有输入文件名前缀时不自动选择文件。包含引号或 Shell 表达式的命令保留普通 Enter 行为，可用 Tab 明确补全。建议在每次显示前重新检查，已删除的文件和旧建议里附带的其他文件名会被过滤。

灰色建议使用实时补全，不再直接重放历史命令中的文件名。`rm`、`gcc`、`vim` 等命令只会根据当前目录中实际存在的文件提供文件名建议；删除文件或切换目录后，不会再从历史记录提示旧文件名。历史记录仍可通过方向键和 `Ctrl+R` 查找。其他命令的 Enter 只执行已输入的内容，Tab 或右方向键可接受补全。

命令选项不提供灰色自动续写，例如输入 `sudo -i` 后不会再建议 `A`、变成 `-iA`；需要选项补全时可主动按 Tab。按 Enter 执行前会清除没有被接受的灰色建议，保证已提交的命令行不会留下实际未执行的字符。若灰色字符已通过 Tab 或右方向键接受、成为普通输入，则会作为实际命令的一部分执行。

可选的手动项目模板命令仍保留，只有你明确执行才会生成目录，已有目录不会被覆盖：

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

示例仅作为可选模板存放在系统目录，不会复制到家目录。运行 `linux-env-doctor` 可重新检查 C/C++ 编译、Python 虚拟环境与配置文件；首次安装默认执行该检查。

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

**试用新版前无需删除旧目录。** 安装器会备份需要替换的配置，不动 `~/.ssh` 和你的代码目录，例如 `c`、`c-plus-plus`、`datastructure`、`linux`。旧的 `~/.vim` 和 `~/.oh-my-zsh` 可以保留，新配置不会加载它们；已有 `.linux-env-backup-*` 备份也可保留，确认不再需要恢复后再自行清理。

Git 提交身份由你自行设置，例如：

```bash
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"
```

## 参数与版本选择

```bash
bash init_env.sh --help
bash init_env.sh --user alice --no-change-shell

# 无人值守安装：只为已有账号配置环境，不设置主机名、创建用户或修改密码
bash init_env.sh --non-interactive --user alice

# 强制进入向导，需要可用的控制终端
bash init_env.sh --interactive

# 仅在依赖已安装的机器上使用；缺少依赖时会报错
bash init_env.sh --user alice --skip-packages

# 明确需要时跳过安装后的自检
bash init_env.sh --user alice --skip-checks
```

默认在交互终端中启用向导；没有交互终端时自动按无人值守方式运行。`--non-interactive` 可显式关闭向导，使用 `--user` 指定的已有账号，或有效的 `SUDO_USER` / root 默认账号。`--interactive` 强制启用向导，没有可用控制终端时会报错。

默认从入口所属仓库（[GitHub](https://github.com/peacecdt/linux-env) 或 [Gitee](https://gitee.com/peacecdt/linux-env)）的 `main` 下载配置；需要时可手动切换平台、固定版本或使用自己的 fork：

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
