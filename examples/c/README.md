# C17 学习项目

在项目根目录构建、运行与测试，不需要下载外部测试库：

```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build
./build/hello_c
ctest --test-dir build --output-on-failure
```

`include/learning.h` 声明函数，`src/learning.c` 实现函数，`src/main.c` 是入口，
`tests/test_learning.c` 测试普通值、负数、相等值和整数边界。
尝试修改 `maximum` 的实现，再运行测试，观察测试如何定位错误。

用 GDB 调试（Debug 构建包含调试符号）：

```bash
gdb ./build/hello_c
# break maximum
# run
# print left
# print right
# next
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
cmake -S . -B build-clang -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_C_COMPILER=clang
cmake --build build-clang
ctest --test-dir build-clang --output-on-failure
```

用安装的 `clang-format` 整理代码：

```bash
clang-format -style=LLVM -i include/learning.h src/learning.c src/main.c tests/test_learning.c
```

在项目根目录打开 Vim 后，`:make` 执行 `cmake --build build`；先 `:w` 保存修改。
`:copen` 查看编译错误，`:cnext` 跳到下一个错误。
运行 `ctags -R --exclude=build --exclude=build-asan --exclude=build-clang .` 建立索引，
Vim 用 `Ctrl-]` 跳到定义、`Ctrl-t` 返回。生成的 `build*/` 和 `tags` 不提交到 Git。
