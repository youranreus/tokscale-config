# tokscale-config

同步个人 [tokscale](https://tokscale.ai) 配置的仓库。仓库内的 `config/` 是唯一事实来源，通过 `link.sh` 软链到本机的 tokscale 配置目录，改动直接反映到工具，也直接可以提交。

目前只存放 `custom-pricing.json`（自定义模型定价）。

## 目录结构

```
config/
└── custom-pricing.json    软链到 ~/.config/tokscale/custom-pricing.json
link.sh                    建链 / 拆链脚本
```

`config/` 镜像 tokscale 配置目录的结构，以后要同步别的配置（比如 `settings.json`），把文件放进 `config/` 顶层再跑一次 `link.sh` 即可，脚本会自动识别，不用改代码。

## 用法

新机器上 clone 之后跑：

```bash
./link.sh
```

其他参数：

```bash
./link.sh --dry-run    # 只打印将要执行的操作，不落盘
./link.sh --unlink     # 拆除软链，把仓库内容拷回成真实文件
```

目标位置若已存在真实文件，脚本会先和仓库版本比对 hash：内容一致直接替换，不一致则备份成 `xxx.bak.20260903-113200` 再替换，不会丢数据。

## 配置目录位置

默认按 `${TOKSCALE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/tokscale}` 解析，macOS 上即 `~/.config/tokscale`。路径不同的机器可以覆盖：

```bash
TOKSCALE_CONFIG_DIR=/path/to/tokscale ./link.sh
```

## 关于凭据

tokscale 配置目录里的 `credentials.json`、`codex-credentials.json`、`cursor-credentials.json`、`device.json` 属于凭据，**不要放进本仓库**。`.gitignore` 已做黑名单拦截，`link.sh` 遇到这些文件名也会直接拒绝处理。
