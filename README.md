# dsh-plugins

DeepSeek Harness（DSH）desktop profile 的插件备份。换电脑、重装、或 profile 搞坏了，一句话把插件全装回来。

## 一句话安装

在 DSH 对话框里对 agent 说（点右边图标复制）：

```
装回插件
```

就这四个字。agent 会读本仓库的 `plugins.json`，执行 `dsh plugin --profile desktop add`（11 个包，版本按清单锁死），把 `bundles` 顺序写回 profile，校验 `node_modules`，然后提示你重启。全程不用你碰命令行。

反向操作（把当前已装的插件写回本仓库）说：

```
同步插件库
```

前提：这台机器上 DSH 能正常启动、agent 有 shell。**DSH 崩了打不开、或新电脑还没装 DSH 时**，用下面这一行。

### 新电脑第一次

新机器上没有旧的 `AGENTS.md`，agent 不知道这个库存在。第一次由你带上链接说一句（点右边图标复制）：

```
装回插件 https://github.com/ctdlb/dsh-plugins
```

agent 读完本页就会自己装。装完把 [AGENTS.md](AGENTS.md) 里那段贴进新机器的 `AGENTS.md`（也可以直接让 agent 追加），之后这台机器也能只靠「装回插件」四个字。

## 命令行安装（没有 agent 时）

在装了 DSH 的机器上打开 PowerShell，粘贴：

```powershell
irm https://raw.githubusercontent.com/ctdlb/dsh-plugins/main/install.ps1 | iex
```

或者把仓库下载下来，双击 `install.cmd`（它会调 `install.ps1`，带 `pause` 方便看输出）。

脚本做四件事：

1. 找 `dsh` 命令行入口（PATH 上没有就按常见安装路径找）
2. 按 `plugins.json` 逐个 `dsh plugin --profile desktop add 包@版本`
3. 把 `bundles` 加载顺序写回 `~/.dsh/profiles/desktop/package.json`（顺序有讲究，见下）
4. 校验 `node_modules` 里每个包都在，然后提示重启

> **装完必须完全退出 DSH（托盘 → 退出）再打开。** 插件只在启动时装配，关窗口不算退出。

只想看会发生什么、不实际安装：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -DryRun
```

## 当前插件（11 个）

| 包 | 版本 | 作用 |
| --- | --- | --- |
| `dsh-my-guardian` | 0.4.6 | 插件护栏：启动期静态预检，写好插件的候选区隔离 |
| `dsh-whale-widget` | 0.4.2 | 鲸鱼娘余额挂件 |
| `@michengai/dsh-archive-manager` | 1.1.6 | 会话归档 |
| `dshmarket` | 1.66.45 | 插件市场 |
| `dsh-ops` | 0.4.1 | 工具层省 token：bash 替代 PowerShell、动态工具加载、PTC 结构化工具 |
| `billion-context` | 0.1.202 | 上下文压缩（接管 `compaction-basic`） |
| `dsh-better-sidebar` | 0.28.0 | 侧边栏 |
| `dsh-browser-cdp` | 1.3.0 | CDP 浏览器 + 侧栏实时观察窗 |
| `cc-safety-net` | 2.6.16 | 命令执行前拦截（拦破坏性 git / rm / 敏感文件读取） |
| `@michengai/dsh-skills-manager` | 1.2.9 | 技能管理面板 |
| `dsh-ui-scale` | 0.1.5 | 界面全局缩放 |

> 版本锁死在这份清单里。想升级就手动改个版本号，或让 agent 重新同步。

## 加载顺序为什么在这个仓库里

`bundles` 的数组顺序 = 插件装配顺序，不是字母序：

```
1  @deepseek-ai/dsh-base        ← 宿主基础层，提供 webServer/settings/loader
2  @deepseek-ai/dsh-web-app     ← 宿主基础层
3  dsh-my-guardian              ← 看门狗，必须最先加载（README 明确要求）
4  dsh-whale-widget
5  @michengai/dsh-archive-manager
6  dshmarket
7  dsh-ops
8  billion-context
9  dsh-better-sidebar
10 dsh-browser-cdp
11 cc-safety-net
12 @michengai/dsh-skills-manager
13 dsh-ui-scale
```

两条规则：

- `@deepseek-ai/*` 两个宿主层不能被顶掉，guardian 要消费它们提供的服务。
- `dsh-my-guardian` 要排在其余插件之前，否则护栏起来时插件已经开始加载了。

`install.ps1` 会自动按这个顺序重排，不用手动改。

## 文件

| 文件 | 说明 |
| --- | --- |
| `plugins.json` | 机器可读清单：`bundles` 顺序 + `dependencies` 版本。同步时只改这个和快照。 |
| `install.ps1` | 一键恢复脚本（ASCII only，避免 PowerShell 5.1 按 ANSI 读中文乱码） |
| `install.cmd` | 双击入口 |
| `snapshot/package.json` | profile 原始配置快照 |
| `snapshot/cordis.patch.yml` | profile 补丁层原始快照（模型/UI/ops 等配置） |

## 更新

以后装了新插件，告诉 agent「同步插件库」即可：它读 `~/.dsh/profiles/desktop/package.json`，重写 `plugins.json` 和 `snapshot/`，再推上来。

手动同步也行：改 `plugins.json` 里的 `dependencies` 和 `bundles`，提交推送。

## 不包含什么

- **会话记录**（在 `~/.dsh/sessions`）—— 这个仓库只管插件，不管对话历史。
- **凭据 / 登录态**（`~/.dsh/.credentials.yaml` 等）。
- **插件自己的运行时数据**（插件目录里的 settings、缓存、账本）。
