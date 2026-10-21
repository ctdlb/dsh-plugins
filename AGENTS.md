# 给 agent 的说明（新电脑用这份）

本仓库是 `ctdlb` 的 DSH（DeepSeek Harness）插件备份。以下几段可以直接贴进任意 DSH 工作区的 `AGENTS.md`，让新机器上的 agent 知道这个库存在。

## 装回插件

用户说「**装回插件**」时：

0. **先问一句「配置文件（插件参数、权限预设等）也一起恢复吗」**，等答复再动手；不想恢复就加 `-SkipConfig`，只装插件
1. 读本仓库 `plugins.json`（`https://raw.githubusercontent.com/ctdlb/dsh-plugins/main/plugins.json`）
2. 执行 `dsh plugin --profile desktop add <每个 包@版本>`；找不到 `dsh` 就用 `install.ps1`（它会自己找 CLI）
3. 把 `bundles` 顺序写回 `~/.dsh/profiles/desktop/package.json`（`dsh-my-guardian` 排在插件第一位，前面只留 `@deepseek-ai/dsh-base`、`@deepseek-ai/dsh-web-app` 两个宿主层）
4. 按 `plugins.json` 的 `configFiles` 把配置写回去（`snapshot/cordis.patch.yml` → `profiles/desktop/cordis.patch.yml`、`pnpm-workspace.yaml`、`.dsh-market/state.json`；覆盖前留 `.bak`）
5. 校验 `node_modules` 里每个包都在
6. 提示用户**完全退出 DSH（托盘 → 退出）再启动**——插件只在启动时装配

## 同步插件库

用户说「**同步插件库**」时：

1. 读 `~/.dsh/profiles/desktop/package.json`
2. 重写本仓库 `plugins.json`（`dependencies` 全量 + `bundles` 原顺序）和 `snapshot/package.json`
3. 同步配置原件：`snapshot/cordis.patch.yml`、`snapshot/pnpm-workspace.yaml`、`snapshot/dsh-market-state.json`（源：`profiles/desktop/cordis.patch.yml`、`pnpm-workspace.yaml`、`.dsh-market/state.json`）
4. 通过 `api.github.com` 的 Contents API 推送（需要 GitHub 令牌；不要写进任何文件）

**上传插件必须同时上传配置文件**，只传清单不算数。改了插件设置（UI 缩放、权限预设、侧栏开关等）之后也要同步一次。

## 要贴进 AGENTS.md 的片段

```markdown
## DSH 插件备份库

- 仓库：`ctdlb/dsh-plugins`（公开）—— `https://github.com/ctdlb/dsh-plugins`。存 DSH `desktop` profile 的插件清单（`plugins.json`：包名 + 锁定版本 + `bundles` 加载顺序 + `configFiles` 配置清单）、`install.ps1` 一键恢复脚本，以及 `snapshot/` 下的 `package.json`、`cordis.patch.yml`、`pnpm-workspace.yaml`、`dsh-market-state.json` 原件。
- 用户说「**装回插件**」时：读该仓库 `plugins.json`，执行 `dsh plugin --profile desktop add <包@版本…>`，把 `bundles` 顺序写回 `~/.dsh/profiles/desktop/package.json`，按 `configFiles` 写回配置（覆盖前留 `.bak`），校验 `node_modules`，最后提示用户完全退出 DSH 再启动。
- 用户说「**同步插件库**」时：读本机 profile 的 `package.json` 与三个配置原件，重写仓库里的 `plugins.json` 与 `snapshot/`，推上去。改了插件设置也要同步。
- 新装插件、升级版本后要同步；仓库不含会话记录、凭据与缓存。
```

## 没有 agent 时

```powershell
irm https://raw.githubusercontent.com/ctdlb/dsh-plugins/main/install.ps1 | iex
```

适用于 DSH 崩溃打不开、或新电脑还没装 DSH 的情况。
