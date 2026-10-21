# dsh-plugins

这个仓库存的是「我这台机器装了哪些 DSH 插件、什么版本、按什么顺序加载」。换电脑、重装、或 profile 崩了，用它把插件本体装回来。

**只备份插件，不备份配置。** 插件的设置（模型、UI、权限预设、侧栏、缩放）留在本机 profile 里，不往这个仓库放 —— 旧配置搬到新机器上反而会把新装的 DSH 配坏。装回来之后按自己习惯重新设一遍，比恢复一份过期配置安全。

仓库不存会话、不存凭据。

---

## 两个动作，方向相反

| 你说什么 | 方向 | 结果 |
| --- | --- | --- |
| **装回插件** | 本仓库 → 你这台机器 | 按清单把 13 个插件装回来，顺带放好配音用的小工具 |
| **同步插件库** | 你这台机器 → 本仓库 | 把当前装的插件和版本写进清单并推送 |

两个都是**对 DSH 里的 agent 说**，不是我敲命令行。下面分别说明什么时候用哪个。

---

## 一、装回插件（库 → 本机）

### 日常：这台机器已经能开 DSH

在 DSH 对话框里对 agent 说：

```
装回插件
```

agent 会做完这些事：

1. 读本仓库的 `plugins.json`（包名 + 锁定版本 + 加载顺序）
2. 执行 `dsh plugin --profile desktop add`，把 13 个包按锁死的版本装上
3. 按清单重排 `~/.dsh/profiles/desktop/package.json` 里的 `bundles` 顺序
4. 把配音用的三个小文件放进 `~/.dsh`（详见下面「三、配音」）
5. 检查 `node_modules` 里每个包都在，然后提醒你重启

**不会碰你的设置**：`cordis.patch.yml`、市场设置、pnpm 配置都不动。装完 DSH 里的插件开关、权限预设、UI 缩放还是你原来的样子；换机器就是全新默认值，需要什么自己再调。

### 新电脑：agent 还不知道有这个库

新机器上没有旧的 `AGENTS.md`，agent 不可能自己找到这里。**第一次**你得带上链接说：

```
装回插件 https://github.com/ctdlb/dsh-plugins
```

装完之后，把 [AGENTS.md](AGENTS.md) 里那段贴进新机器的 `AGENTS.md`（也可以直接让 agent 追加）。之后这台机器也能只靠「装回插件」四个字。

### DSH 打不开：没有 agent 可用

插件装坏导致 DSH 起不来时，agent 也没了。这种情况用命令行，在 PowerShell 里粘：

```powershell
irm https://raw.githubusercontent.com/ctdlb/dsh-plugins/main/install.ps1 | iex
```

或者把仓库下载下来，双击 `install.cmd`（它调 `install.ps1`，结尾 `pause`，方便看输出）。

只想看会发生什么、不实际安装：

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -DryRun
```

**不管用哪种方式，装完都要完全退出 DSH（托盘图标 → 退出）再打开。** 插件只在启动时装配，关窗口不算退出。

---

## 二、同步插件库（本机 → 库）

以后你新装了插件，或升级了某个插件的版本，对 agent 说：

```
同步插件库
```

agent 会读 `~/.dsh/profiles/desktop/package.json`，把新的 `dependencies` 和 `bundles` 写进仓库里的 `plugins.json`，然后推送。只同步插件清单，配置文件一律不进仓库。

手动改也行：直接编辑 `plugins.json` 里的 `dependencies`（版本）和 `bundles`（顺序），提交推送。

这个仓库不会自动更新——装完新插件不说一句，仓库里还是旧的。

---

## 三、配音（可选，默认关闭）

`dsh-answer-me-with-html` 默认只出画面 + 字幕，**不配音**，也不会留任何后台进程。

要配音时对 agent 说一句「要配音」，它会：

1. 跑 `~/.dsh/tts-start.ps1` 起本地小服务（`http://127.0.0.1:18321`）
2. 用它渲染 `--voice local` 的视频
3. 渲染完（哪怕报错）立刻跑 `~/.dsh/tts-stop.ps1` 关掉

为什么需要这层小服务：`am` 只认 ElevenLabs 或「OpenAI 兼容的本地 TTS 接口」，不认 Azure；`tts-shim.mjs` 就是把后者翻译成 Azure 语音（默认晓晓高清一代）。密钥只在运行时从 Windows 凭据管理器 `TextToTalk_AccessKeys_AzureCognitiveServices` 读，**仓库里、脚本里都不存密钥**。

念数字的问题：Azure 会把 `999` 念成「九百九十九」，急救号码必须一字一顿。起服务时加一条环境变量即可，草稿里写的还是 `999`，字幕不受影响：

```powershell
$env:AM_TTS_SUBS = '{"999":"九九九","120":"一二零","110":"一一零","119":"一一九"}'
```

`AM_TTS_SUBS` 是 JSON 的「原文 → 念法」替换表，按 key 长度从长到短替换；`/health` 里的 `subs` 字段能看出生效了几条。

手动起停（一般用不上，agent 会自己做）：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.dsh\tts-start.ps1"
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.dsh\tts-stop.ps1"
```

几个容易踩的点：

- 360 曾把 `tts-start.ps1` 报成「木马病毒」——误报（读凭据 + `Add-Type` 编译 + 隐藏窗口 + 本地监听凑齐了木马特征）。把这两个脚本加进 360 信任区即可，别让它删掉。
- 换了音色却还是旧声音：`~/.answer-me-with-html/cache/tts` 按文本哈希缓存音频，**换音色前先清空该目录**。
- `--voice system` 在 Windows 上等于没声音（只有 macOS `say` / Linux `espeak-ng`）。

---

## 仓库里有什么

| 文件 | 说明 |
| --- | --- |
| `plugins.json` | 机器可读清单：13 个包的锁定版本 + 15 条 `bundles` 加载顺序 |
| `install.ps1` | 一键恢复脚本（装插件 + 排加载顺序 + 放好配音小工具；`-SkipInstall` 只排顺序，`-SkipTts` 不装配音工具，`-DryRun` 只看计划）。ASCII only，避免 PowerShell 5.1 按 ANSI 读中文乱码 |
| `install.cmd` | 双击入口，调 `install.ps1` |
| `tts/` | 可选的配音工具：`tts-shim.mjs`（Azure 转换层）、`tts-start.ps1`、`tts-stop.ps1`。`install.ps1` 会把它们复制到 `~/.dsh` |
| `AGENTS.md` | 给 agent 的规则片段，可贴进新机器的 `AGENTS.md` |

没有 `snapshot/` 了：配置文件不再备份，装回来只拿插件本体。

`plugins.json` 长这样：

```json
{
  "profile": "desktop",
  "dependencies": { "dsh-my-guardian": "0.4.6", "...": "..." },
  "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "dsh-my-guardian", "..."]
}
```

---

## 当前清单（13 个插件）

| 包 | 版本 | 作用 |
| --- | --- | --- |
| `dsh-my-guardian` | 0.4.6 | 插件护栏：启动期静态预检，新插件先进候选区隔离 |
| `dsh-whale-widget` | 0.4.2 | 鲸鱼娘余额挂件 |
| `@michengai/dsh-archive-manager` | 1.1.6 | 会话归档 |
| `dshmarket` | 1.66.45 | 插件市场 |
| `dsh-ops` | 0.4.1 | 工具层省 token：bash 替代 PowerShell、动态工具加载、结构化工具 |
| `billion-context` | 0.1.202 | 上下文压缩，接管 `compaction-basic` |
| `dsh-better-sidebar` | 0.28.0 | 侧边栏 |
| `dsh-browser-cdp` | 1.3.0 | CDP 浏览器 + 侧栏实时观察窗 |
| `dsh-context` | 0.74.0 | 上下文看板：组成/趋势/费用/文件活动，右栏面板 + `/context` 命令 |
| `cc-safety-net` | 2.6.16 | 命令执行前拦截破坏性操作 |
| `@michengai/dsh-skills-manager` | 1.2.9 | 技能管理面板 |
| `dsh-ui-scale` | 0.1.5 | 界面全局缩放 |
| `dsh-answer-me-with-html` | 0.5.0 | 把回答做成可视化 HTML 页/动画（技能包，附 `am` 命令） |

版本锁定在这份清单里。要升级：改这里的版本号，或升级完对 agent 说「同步插件库」。

---

## 加载顺序（15 条，不是 13 条）

`bundles` 数组顺序 = 插件装配顺序，跟字母序无关。前面两条是宿主自带的基础层，所以 15 条里只有 13 条来自上面那张表：

```
1  @deepseek-ai/dsh-base        ← 宿主基础层，提供 webServer / settings / loader
2  @deepseek-ai/dsh-web-app     ← 宿主基础层
3  dsh-my-guardian              ← 看门狗，必须在其余插件之前加载
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
14 dsh-context
15 dsh-answer-me-with-html
```

两条硬规则：

- `@deepseek-ai/*` 两个宿主层必须留在最前，`dsh-my-guardian` 要用它们提供的服务。
- `dsh-my-guardian` 要排在所有第三方插件之前，否则护栏醒来时插件已经在加载了。

`install.ps1` 和 agent 都会按上面的顺序自动重排，不用手改。

---

## 不包含什么

- **会话记录**（`~/.dsh/sessions`）—— 这个仓库只管插件，不管聊天历史。
- **凭据 / 登录态**（`~/.dsh/.credentials.yaml`、`.dshw-usage.json` 等）。
- **Azure 语音密钥** —— 它只存在 Windows 凭据管理器（`TextToTalk_AccessKeys_AzureCognitiveServices`），`tts/` 里的脚本是运行时去读，仓库和脚本本身都不含密钥。
- **插件配置**（`profiles/desktop/cordis.patch.yml`、`.dsh-market/state.json`、`pnpm-workspace.yaml`）—— 这是有意不备份的：旧配置搬到新机器上会把新环境配坏（比如把已卸载插件的开关、旧权限预设写回去）。插件装好之后自己调一遍更省事。
- **插件自己的缓存与日志**（`~/.dsh/storages/session_projcache*`、`.plugin-manager/logs`、`guardian/state.json` 的运行时事件）—— 重装后会自动重建。

---

## 出处

本机工作区是 `E:\DeepSeek Harness`，`desktop` profile 在 `C:\Users\ctdlb\.dsh\profiles\desktop`。别处用同一套 DSH 目录结构（`~/.dsh/...`），脚本按运行时实际路径计算，不写死盘符。
