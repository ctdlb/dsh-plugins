# 给 agent 的说明（新电脑用这份）

本仓库是 `ctdlb` 的 DSH（DeepSeek Harness）插件备份。以下几段可以直接贴进任意 DSH 工作区的 `AGENTS.md`，让新机器上的 agent 知道这个库存在。

**只备份插件本体，不备份任何配置。**

## 装回插件

用户说「**装回插件**」时：

1. 读本仓库 `plugins.json`（`https://raw.githubusercontent.com/ctdlb/dsh-plugins/main/plugins.json`）
2. 执行 `dsh plugin --profile desktop add <每个 包@版本>`；找不到 `dsh` 就用 `install.ps1`（它会自己找 CLI）
3. 把 `bundles` 顺序写回 `~/.dsh/profiles/desktop/package.json`（`dsh-my-guardian` 排在插件第一位，前面只留 `@deepseek-ai/dsh-base`、`@deepseek-ai/dsh-web-app` 两个宿主层）
4. 校验 `node_modules` 里每个包都在
5. 提示用户**完全退出 DSH（托盘 → 退出）再启动**——插件只在启动时装配

不要碰 `cordis.patch.yml`、`.dsh-market/state.json`、`pnpm-workspace.yaml` 这些配置文件：仓库里根本没有它们，旧配置搬到新机器上会把环境配坏。用户问起就这么解释。

## 同步插件库

用户说「**同步插件库**」时：

1. 读 `~/.dsh/profiles/desktop/package.json`
2. 重写本仓库 `plugins.json`（`dependencies` 全量 + `bundles` 原顺序）
3. 通过 `api.github.com` 推送（Git Data API 一次原子提交；令牌从凭据管理器读，不要写进任何文件）

只同步插件清单，配置文件一律不进仓库。

## 配音（可选）

`tts/` 里是配音用的小工具（`tts-shim.mjs` 把 Azure 语音包装成 OpenAI 兼容接口，加两个起停脚本），`install.ps1` 会把它们复制到 `~/.dsh`。

- **默认不配音、不起服务**：渲染视频用 `--voice off`。
- 用户说「要配音」时，agent 自己走完整流程：`~/.dsh/tts-start.ps1` → 渲染 `--voice local` → `~/.dsh/tts-stop.ps1`；**渲染报错也要执行收尾**，不能留下监听进程。
- 密钥只在 Windows 凭据管理器里，脚本运行时才读；任何文件、日志、提交都不得写入密钥。
- 换音色前先清空 `~/.answer-me-with-html/cache/tts`，否则会命中旧音色的缓存音频。

## 要贴进 AGENTS.md 的片段

```markdown
## DSH 插件备份库

- 仓库：`ctdlb/dsh-plugins`（公开）—— `https://github.com/ctdlb/dsh-plugins`。存 DSH `desktop` profile 的插件清单（`plugins.json`：包名 + 锁定版本 + `bundles` 加载顺序）和 `install.ps1` 一键恢复脚本。**只备份插件本体，不备份配置。**
- 用户说「**装回插件**」时：读该仓库 `plugins.json`，执行 `dsh plugin --profile desktop add <包@版本…>`，把 `bundles` 顺序写回 `~/.dsh/profiles/desktop/package.json`，校验 `node_modules`，最后提示用户完全退出 DSH 再启动。不要动 `cordis.patch.yml` 等配置文件。
- 用户说「**同步插件库**」时：读本机 profile 的 `package.json`，重写仓库里的 `plugins.json`，推上去。
- `install.ps1` 顺带把仓库 `tts/` 里的配音小工具复制到 `~/.dsh`。默认不配音、不起任何服务；用户说「要配音」时才由 agent `tts-start.ps1` → 渲染 `--voice local` → `tts-stop.ps1`，用完即关。
- 新装插件、升级版本后要同步；仓库不含配置、会话记录与凭据。
```

## 没有 agent 时

```powershell
irm https://raw.githubusercontent.com/ctdlb/dsh-plugins/main/install.ps1 | iex
```

适用于 DSH 崩溃打不开、或新电脑还没装 DSH 的情况。
