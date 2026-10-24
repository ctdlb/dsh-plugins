# dsh-plugins

把我这台机器上的 DSH 插件记成一份清单：**装了什么、什么版本、按什么顺序加载**。换电脑、重装、profile 崩了，用它把插件本体装回来。

> **只备份插件本体。** 配置（模型、UI、权限预设、侧栏、缩放）、会话记录、凭据、缓存都不进这个仓库——旧配置搬到新机器上会把新环境配坏，装完自己调一遍更省事。

---

## 怎么用

| 想做什么 | 对 DSH 里的 agent 说 | 方向 |
| --- | --- | --- |
| 装回来 | `装回插件` | 本仓库 → 本机 |
| 更新清单 | `同步插件库` | 本机 → 本仓库 |

两句话都是对 agent 说的，不用自己敲命令。**唯一例外是 DSH 已经起不来**（插件装坏、没有 agent 可用），那时走下面的命令行。

---

## 一、装回来

### 日常：DSH 能开

```
装回插件
```

agent 会依次做：

1. 读 `plugins.json`（包名 + 锁定版本 + 加载顺序）
2. `dsh plugin --profile desktop add …` 按锁死版本装 13 个包
3. 按清单重排 `~/.dsh/profiles/desktop/package.json` 的 `bundles`
4. 把 `tts/` 三个配音小文件放进 `~/.dsh`
5. 校验 `node_modules`，提醒你重启

**装之前会先告诉你 DSH 装在哪**（`DSH CLI : …`），确认了才动手。找不到就停下来问你要目录，不会盲装。

不碰设置：`cordis.patch.yml`、市场设置、pnpm 配置一律不动。

### 新电脑：agent 还不知道有这个库

第一次带上链接：

```
装回插件 https://github.com/ctdlb/dsh-plugins
```

装完后把 [AGENTS.md](AGENTS.md) 复制到 `%USERPROFILE%\.dsh\AGENTS.md`（也可以让 agent 去复制）。这份与生效那份**逐字一致**，原样复制，不用改任何一行；想确认是否同步，比 SHA256 就行。之后这台机器只靠「装回插件」四个字。

### DSH 打不开：没有 agent

PowerShell 里粘：

```powershell
irm https://raw.githubusercontent.com/ctdlb/dsh-plugins/main/install.ps1 | iex
```

或者把仓库下载下来双击 `install.cmd`（调 `install.ps1`，结尾 `pause` 方便看输出）。

先看会发生什么、不实际安装：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -DryRun
```

**DSH 不在默认位置**：脚本按 PATH → `Program Files` → `Program Files (x86)` → `LOCALAPPDATA\Programs` → 常见 D 盘位置找 `dsh.cmd`，`-DryRun` 会把找到的路径打出来。全都没找到就停下，让你指定：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -DshPath '<安装目录>\resources\runtime\cli\bin\dsh.cmd'
```

配音脚本 `tts-start.ps1` 同样自己找 `DeepSeek Harness.exe`（`DSH_EXE` → Program Files → Program Files (x86) → `LOCALAPPDATA\Programs` → D 盘），找不到会提示设 `DSH_EXE`。

### 装完必须重启

插件只在 DSH 启动时装配。**完全退出**（托盘图标 → 退出，确认任务管理器里没有进程）再打开，关窗口不算退出。

### install.ps1 的开关

| 参数 | 作用 |
| --- | --- |
| `-DryRun` | 只打印计划，不写任何东西 |
| `-SkipInstall` | 不装包，只重排 `bundles` |
| `-SkipTts` | 不复制配音小工具 |
| `-DshPath <path>` | 手动指定 `dsh.cmd` |

---

## 二、同步清单

新装了插件或升级了版本：

```
同步插件库
```

agent 读 `~/.dsh/profiles/desktop/package.json`，把 `dependencies` 和 `bundles` 写进 `plugins.json` 并推送。只同步清单，配置一律不进。

手动也行：直接改 `plugins.json` 的 `dependencies`（版本）和 `bundles`（顺序），提交推送。

仓库不会自动更新——装完新插件不说一句，这里还是旧的。

---

## 三、配音（可选，默认关闭）

`dsh-answer-me-with-html` 默认只出画面 + 字幕，不配音，也不留后台进程。

说要配音时，agent 会：

1. 跑 `~/.dsh/tts-start.ps1` 起本地服务（`http://127.0.0.1:18321`）
2. 用它渲染 `--voice local` 的视频
3. 渲染完（哪怕报错）立刻跑 `~/.dsh/tts-stop.ps1` 关掉

为什么需要这层：`am` 只认 ElevenLabs 或「OpenAI 兼容的本地 TTS 接口」，不认 Azure；`tts-shim.mjs` 把后者翻译成 Azure 语音（默认晓晓高清一代）。密钥运行时从 Windows 凭据管理器 `TextToTalk_AccessKeys_AzureCognitiveServices` 读，**仓库和脚本里都不存密钥**。

**数字要一字一顿**：Azure 会把 `999` 念成「九百九十九」。起服务时加环境变量，草稿里照写 `999`，字幕不受影响：

```powershell
$env:AM_TTS_SUBS = '{"999":"九九九","120":"一二零","110":"一一零","119":"一一九"}'
```

它是 JSON 的「原文 → 念法」表，按 key 长度从长到短替换；`/health` 的 `subs` 字段显示生效几条。

手动起停（一般用不上，agent 自己做）：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.dsh\tts-start.ps1"
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.dsh\tts-stop.ps1"
```

几个坑：

- 360 曾把 `tts-start.ps1` 报成「木马病毒」——误报（读凭据 + `Add-Type` + 隐藏窗口 + 本地监听凑齐了木马特征）。加进 360 信任区，别让它删。
- 换了音色却还是旧声音：`~/.answer-me-with-html/cache/tts` 按文本哈希缓存，**换音色前先清空**。
- `--voice system` 在 Windows 上等于没声音（只有 macOS `say` / Linux `espeak-ng`）。

---

## 仓库里有什么

| 文件 | 说明 |
| --- | --- |
| `plugins.json` | 机器可读清单：13 个包的锁定版本 + 15 条 `bundles` 顺序 |
| `install.ps1` | 一键恢复：装插件 + 排顺序 + 放配音工具。ASCII only，避免 PowerShell 5.1 按 ANSI 读中文出错 |
| `install.cmd` | 双击入口，调 `install.ps1` |
| `tts/` | 可选配音工具：`tts-shim.mjs`（Azure 转换层）、`tts-start.ps1`、`tts-stop.ps1`；安装时复制到 `~/.dsh` |
| `AGENTS.md` | 用户级规则 `%USERPROFILE%\.dsh\AGENTS.md` 的备份，与生效那份逐字一致 |

没有 `snapshot/`：配置文件不备份。

`plugins.json` 结构：

```json
{
  "profile": "desktop",
  "updatedAt": "2026-10-24",
  "bundles": ["@deepseek-ai/dsh-base", "…"],
  "dependencies": { "dsh-my-guardian": "0.4.6", "…": "…" }
}
```

---

## 插件清单（13 个）

| 包 | 版本 | 作用 |
| --- | --- | --- |
| `dsh-my-guardian` | 0.4.6 | 护栏：启动期静态预检，新插件先进候选区隔离 |
| `dsh-whale-widget` | 0.4.2 | 鲸鱼娘余额挂件 |
| `@michengai/dsh-archive-manager` | 1.1.6 | 会话归档 |
| `dshmarket` | 1.66.45 | 插件市场 |
| `dsh-ops` | 0.4.1 | 工具层省 token：bash、动态工具加载、结构化工具 |
| `billion-context` | 0.1.204 | 上下文压缩，接管 `compaction-basic`（**锁 0.1.204**，0.1.203 会触发 `tool_addition` 崩溃） |
| `dsh-better-sidebar` | 0.28.0 | 侧边栏 |
| `dsh-browser-cdp` | 1.3.0 | CDP 浏览器 + 侧栏实时观察窗 |
| `dsh-context` | 0.74.0 | 上下文看板：组成/趋势/费用，右栏面板 + `/context` |
| `cc-safety-net` | 2.6.16 | 命令执行前拦截破坏性操作 |
| `@michengai/dsh-skills-manager` | 1.2.9 | 技能管理面板 |
| `dsh-ui-scale` | 0.1.5 | 界面全局缩放 |
| `dsh-answer-me-with-html` | 0.5.0 | 把回答做成可视化 HTML 页/动画（技能包，附 `am` 命令） |

版本锁在这张表里。升级：改版本号，或升级完说「同步插件库」。

---

## 加载顺序（15 条，不是 13 条）

`bundles` 顺序 = 装配顺序，跟字母序无关。前两条是宿主基础层，所以 15 条里只有 13 条来自上表。

```
 1  @deepseek-ai/dsh-base         宿主基础层（webServer / settings / loader）
 2  @deepseek-ai/dsh-web-app      宿主基础层
 3  dsh-my-guardian               护栏，必须在其余插件之前
 4  dsh-whale-widget
 5  @michengai/dsh-archive-manager
 6  dshmarket
 7  dsh-ops
 8  billion-context
 9  dsh-better-sidebar
10  dsh-browser-cdp
11  cc-safety-net
12  @michengai/dsh-skills-manager
13  dsh-ui-scale
14  dsh-context
15  dsh-answer-me-with-html
```

两条硬规则：

- 两个 `@deepseek-ai/*` 宿主层必须在最前——`dsh-my-guardian` 要用它们的服务。
- `dsh-my-guardian` 必须排在所有第三方插件之前，否则护栏醒来时插件已经在加载了。

`install.ps1` 和 agent 都会按这个顺序重排，不用手改。

---

## 不包含什么

- **配置**：`cordis.patch.yml`、`.dsh-market/state.json`、`pnpm-workspace.yaml`。有意不备份——旧配置会把新环境配坏（已卸载插件的开关、过期权限预设、失效的 pnpm 排除项）。
- **会话记录**：`~/.dsh/sessions`。
- **凭据 / 登录态**：`~/.dsh/.credentials.yaml`、`.dshw-usage.json`。
- **Azure 语音密钥**：只在 Windows 凭据管理器，`tts/` 里的脚本运行时去读。
- **缓存与日志**：`~/.dsh/storages/session_projcache*`、`.plugin-manager/logs`、`guardian/state.json`，重装后自动重建。

---

## 说明

本机工作区在 `E:\DeepSeek Harness`，profile 在 `%USERPROFILE%\.dsh\profiles\desktop`（用户名随机器变，别写死 `C:\Users\<名字>`）。所有脚本按运行时实际路径计算，不写死盘符，换机不用改。
