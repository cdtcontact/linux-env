# 从小项目开始学习

安装完成后，先切换到自己的普通账号。`linux-env-new` 会把模板复制到**尚不存在**的目标目录：

```bash
linux-env-new c ~/code/hello-c
linux-env-new cpp ~/code/hello-cpp
linux-env-new python ~/code/hello-python
```

这些模板没有联网下载源码或测试框架的步骤。也可以直接在本仓库对应的 `examples/c`、
`examples/cpp`、`examples/python` 目录运行下面的命令。

## C / C++：构建、测试、调试

以 C++ 为例：

```bash
cd ~/code/hello-cpp
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
ctest --test-dir build --output-on-failure
./build/hello_cpp
./build/hello_cpp "Ada Lovelace"
```

C 项目使用相同的 CMake / CTest 命令，运行文件改成 `./build/hello_c`。
C 项目使用 C17，C++ 项目使用 C++17；警告默认开启，测试不依赖 `assert`，Release 构建也会执行检查。
`include/` 放头文件，`src/` 放实现和入口，`tests/` 放测试；`build/` 放生成的文件，不提交到 Git。

用 GDB 学习断点、单步和变量：

```bash
gdb --args ./build/hello_cpp Python
# 在 GDB 中依次输入：
# break main
# run
# next
# print argc
# step
# backtrace
# continue
# quit
```

GCC 与 Clang 可以分别构建到不同目录，避免复用另一编译器的缓存：

```bash
cmake -S . -B build-clang -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
cmake --build build-clang
ctest --test-dir build-clang --output-on-failure
```

学习内存错误与未定义行为检查时，可另建一个开启 Sanitizer 的目录：

```bash
cmake -S . -B build-asan -G Ninja -DCMAKE_BUILD_TYPE=Debug -DLEARNING_ENABLE_SANITIZERS=ON
cmake --build build-asan
ctest --test-dir build-asan --output-on-failure
```

## Python：虚拟环境、测试、调试

```bash
cd ~/code/hello-python
python3 -m venv .venv
source .venv/bin/activate
python -m hello_python Python
python -m unittest discover -s tests -v
python -m pdb -m hello_python Python
deactivate
```

详见 [Python 项目说明](python/README.md)。不替换系统 Python，不向系统环境安装 Python 包。

## 编辑与终端

- Vim：空格 `w` 保存，空格 `e` 打开文件树，空格 `b` 执行 `:make`，空格 `q` 打开错误列表，
  `]q` / `[q` 切换错误。先执行 `:w` 保存修改，再 `:make`。C/C++ 的 `:make` 在项目根目录执行
  `cmake --build build`，因此先按上面命令配置一次 CMake。
- Python 的 `:make` 仅检查当前文件语法，优先使用当前文件目录向上查找的 `.venv/bin/python`，
  再使用已激活虚拟环境，最后使用系统 `python3`。测试与程序运行由终端命令明确触发。
- C/C++ 跳转：在项目根目录运行 `ctags -R --exclude=build --exclude=build-clang --exclude=build-asan --exclude=.venv .`，
  Vim 内 `Ctrl-]` 跳到定义，`Ctrl-t` 返回；`:find learning.h` 查找头文件，`:grep maximum .` 搜索代码。
- Zsh：Tab 补全，上/下键按已输入前缀搜索历史。安装了 fzf 时，`Ctrl-r` 搜索历史，`Ctrl-t` 选择文件，
  `Alt-c` 选择目录；`rg maximum .` 搜索文本。`source .zshrc` 应在家目录运行，也可直接 `source ~/.zshrc`。
- tmux：运行 `tmux new -s study`，`Ctrl-b |` 左右分屏，`Ctrl-b -` 上下分屏，
  `Ctrl-b d` 暂时离开，`tmux attach -t study` 回来；`Ctrl-b ?` 查看快捷键。
- Git：首次提交前自行设置 `git config --global user.name "你的名字"` 和
  `git config --global user.email "你的邮箱"`；`git st` 看状态，`git lg` 看最近提交。

个人设置写入 `~/.zshrc.local`、`~/.vimrc.local`、`~/.tmux.conf.local`。
Git 的个人设置直接用 `git config --global` 修改，会优先于本套配置的默认值。
`.editorconfig` 供支持 EditorConfig 的编辑器读取；原生 Vim 的缩进由 `.vimrc` 配置。
