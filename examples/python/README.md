# Python 学习项目

在项目根目录运行。示例使用 Python 3.10+ 和标准库，不需要下载第三方包：

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m hello_python
python -m hello_python "Ada Lovelace"
python -m unittest discover -s tests -v
```

`hello_python/__init__.py` 放业务函数，`__main__.py` 提供命令行入口，`tests/` 放测试。
运行 `deactivate` 退出虚拟环境。下次进入项目后重新 `source .venv/bin/activate`。

调试入口（用 `n` 单步、`p args` 看变量、`c` 继续、`q` 退出）：

```bash
python -m pdb -m hello_python Python
```

需要练习安装自己的 Python 包时，在虚拟环境中执行 `python -m pip install -e .`，然后可以用
`hello-python Python` 命令。这个可选步骤可能从 PyPI 下载构建依赖；运行和测试示例本身无需此步骤。
项目的第三方依赖也应在当前 `.venv` 中安装，不要使用 `sudo pip install`。

安装器若已提供 `ruff`，可在项目根目录运行 `ruff check .` 和 `ruff format .`。
在 Vim 打开 Python 文件后，`:make` 使用就近 `.venv/bin/python` 检查当前文件的语法，
不会运行程序；真正运行和测试时使用上面的终端命令。
