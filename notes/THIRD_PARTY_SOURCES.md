# 第三方来源与许可证核对清单

以下来源是从旧安装脚本里识别出的线索，不表示所有组件都允许无条件重新分发。公开仓库前需要检查相应目录中的 LICENSE/NOTICE，并保留原有版权和许可声明。

| 组件 | 旧脚本中出现的来源 | 整理建议 |
|---|---|---|
| Vim 配置及部分插件 | `https://gitee.com/suyelu/vim.git` | 保留上游 README、LICENSE、NOTICE，以及插件各自的许可文件。该仓库 README 显示 Apache-2.0，但内部插件可能另有许可证。 |
| Vundle | `https://gitee.com/suyelu/vundle.git` | 保留 Vundle 自身的 LICENSE；不要用顶层项目的许可证覆盖它。 |
| Oh My Zsh | `https://gitee.com/suyelu/ohmyzsh.git`（旧脚本构造的地址） | 收集的是当前已安装副本；核对它的 LICENSE 和与上游的差异。 |
| zsh-syntax-highlighting | `https://gitee.com/suyelu/zsh-syntax-highlighting.git` | 保留组件自带的许可证与版权信息。 |
| incr 插件 | 旧脚本的 `http://123.57.201.194/data/incr-0.2.zsh` | 来源是旧 HTTP 下载地址；公开再分发前应确认来源、版权和许可。 |
| `isoftstone_check` | 旧脚本按架构从 `http://123.57.201.194/data/kkb_check_ubuntu_18.04*` 下载 | 这是不透明的旧脚本/二进制；确认来源和用途，检查架构及依赖。不确认许可时不要公开分发。 |

建议在 README 中标明哪些文件来自上游、哪些修改由本仓库维护，并尽量保留完整上游目录与许可文件。
