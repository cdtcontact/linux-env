# C++17 学习项目

在项目根目录构建、运行与测试，不需要下载外部测试库：

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/hello_cpp
./build/hello_cpp "Ada Lovelace"
ctest --test-dir build --output-on-failure
```

`include/greeting.hpp` 声明函数，`src/greeting.cpp` 实现函数，`src/main.cpp` 是入口，
`tests/test_greeting.cpp` 检查普通名字、空字符串、包含空格或特殊字符的输入。
可以从修改函数的输出格式开始，同时更新相应测试。

用 GDB 学习断点、单步与变量：

```bash
gdb --args ./build/hello_cpp Python
# break main
# run
# print argc
# next
# step
# backtrace
# continue
# quit
```

默认开启编译器警告。需要检查内存错误和未定义行为时：

```bash
cmake -S . -B build-asan -G Ninja -DCMAKE_BUILD_TYPE=Debug -DLEARNING_ENABLE_SANITIZERS=ON
cmake --build build-asan
ctest --test-dir build-asan --output-on-failure
```

切换 Clang 时使用单独的构建目录：

```bash
cmake -S . -B build-clang -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_CXX_COMPILER=clang++
cmake --build build-clang
ctest --test-dir build-clang --output-on-failure
```

用安装的 `clang-format` 整理代码：

```bash
clang-format -style=LLVM -i include/greeting.hpp src/greeting.cpp src/main.cpp tests/test_greeting.cpp
```

在项目根目录打开 Vim 后，`:make` 执行 `cmake --build build`；先 `:w` 保存修改。
`:copen` 查看编译错误，`:cnext` 跳到下一个错误。
运行 `ctags -R --exclude=build --exclude=build-asan --exclude=build-clang .` 建立索引，
Vim 用 `Ctrl-]` 跳到定义、`Ctrl-t` 返回。生成的 `build*/` 和 `tags` 不提交到 Git。
