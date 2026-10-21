# dsh-plugins

这个仓库存的是「我这台机器装了哪些 DSH 插件、什么版本、按什么顺序加载」。换电脑、重装、或 profile 崩了，用它原样装回来。

仓库存两样东西：**插件清单**（装哪些、什么版本、按什么顺序加载）+ **配置快照**（补丁层的参数、市场设置）。不存会话、不存凭据。

---

## 两个动作，方向相反

| 你说什么 | 方向 | 结果 |
| --- | --- | --- |
| **装回插件** | 本仓库 → 你这台机器 | 按清单把 11 个插件装回来 |
| **同步插件库** | 你这台机器 → 本仓库 | 把当前装的插件写进清单并推送 |

两个都是**对 DSH 里的 agent 说**，不是我敲命令行。下面分别说明什么时候用哪个。

---

## 一、装回插件（库 → 本机）

### 日常：这台机器已经能开 DSH

在 DSH 对话框里对 agent 说：

```
装回插件
```

agent **会先问你一句「配置文件也一起恢复吗」**，你答完它才动手。之后做完这些事：

1. 读本仓库的 `plugins.json`（包名 + 锁定版本 + 加载顺序 + 配置清单）
2. 执行 `dsh plugin --profile desktop add`，把 11 个包按锁死的版本装上
3. 按清单重排 `~/.dsh/profiles/desktop/package.json` 里的 `bundles` 顺序
4. 你同意的话，把 `configFiles` 列的 3 个配置文件写回去（补丁层参数、pnpm 排除项、市场状态）；不同意就跳过，只装插件
5. 检查 `node_modules` 里每个包都在，然后提醒你重启

### 配置也一起恢复

第 4 步写回的是这三样：

| 文件 | 里面是什么 |
| --- | --- |
| `profiles/desktop/cordis.patch.yml` | 补丁层：默认模型、UI 偏好、`dsh-ops` 策略、`better-sidebar` 的 `agentOpenTools`、`ui-scale` 的 110%、权限预设（`permission`，默认 `danger-full-access`） |
| `profiles/desktop/pnpm-workspace.yaml` | `minimumReleaseAgeExclude` 那几行，少了它 pnpm 可能拒绝安装「太新」的包 |
| `profiles/desktop/.dsh-market/state.json` | 市场分区 `china`、分组、禁用列表 |

默认**覆盖**，覆盖前把原文件留成 `<文件名>.bak`。四个开关：

- `-SkipConfig` —— 只要插件，配置一点不动（你说「不用恢复配置」时 agent 会带上这个）
- `-KeepConfig` —— 已存在的配置文件不覆盖，只补缺失的
- `-SkipInstall` —— 只恢复配置，不重装插件
- `-DryRun` —— 只打印计划，什么都不改

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

agent 会读 `~/.dsh/profiles/desktop/package.json`，把新的 `dependencies` 和 `bundles` 写进仓库里的 `plugins.json`，**同时**同步 `snapshot/` 下的配置文件原件（`package.json`、`cordis.patch.yml`、`pnpm-workspace.yaml`、市场价格 `state.json`），然后推送。

插件清单和配置文件是一起备份的——只传清单不算数。改了插件设置（比如 UI 缩放、权限预设、侧栏开关）之后也同步一次，下次装回来才是改过的配置。

手动改也行：直接编辑 `plugins.json` 里的 `dependencies`（版本）和 `bundles`（顺序），提交推送。

这个仓库不会自动更新——装完新插件不说一句，仓库里还是旧的。

---

## 仓库里有什么

| 文件 | 说明 |
| --- | --- |
| `plugins.json` | 机器可读清单：11 个包的锁定版本 + 13 条 `bundles` 加载顺序 + `configFiles` 配置清单 |
| `install.ps1` | 一键恢复脚本（装插件 + 排加载顺序 + 写回配置）。ASCII only，避免 PowerShell 5.1 按 ANSI 读中文乱码 |
| `install.cmd` | 双击入口，调 `install.ps1` |
| `AGENTS.md` | 给 agent 的规则片段，可贴进新机器的 `AGENTS.md` |
| `snapshot/package.json` | profile 的原始配置快照 |
| `snapshot/cordis.patch.yml` | 补丁层快照：模型、UI、ops、侧栏、缩放的参数 |
| `snapshot/pnpm-workspace.yaml` | pnpm 的 `minimumReleaseAgeExclude` 排除项 |
| `snapshot/dsh-market-state.json` | 插件市场的分区与分组状态 |

`plugins.json` 长这样：

```json
{
  "profile": "desktop",
  "dependencies": { "dsh-my-guardian": "0.4.6", "...": "..." },
  "bundles": ["@deepseek-ai/dsh-base", "@deepseek-ai/dsh-web-app", "dsh-my-guardian", "..."],
  "configFiles": [
    { "source": "snapshot/cordis.patch.yml", "target": "profiles/{profile}/cordis.patch.yml" }
  ]
}
```

---

## 当前清单（11 个插件）

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
| `cc-safety-net` | 2.6.16 | 命令执行前拦截破坏性操作 |
| `@michengai/dsh-skills-manager` | 1.2.9 | 技能管理面板 |
| `dsh-ui-scale` | 0.1.5 | 界面全局缩放 |

版本锁定在这份清单里。要升级：改这里的版本号，或升级完对 agent 说「同步插件库」。

---

## 加载顺序（13 条，不是 11 条）

`bundles` 数组顺序 = 插件装配顺序，跟字母序无关。前面两条是宿主自带的基础层，所以 13 条里只有 11 条来自上面那张表：

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
```

两条硬规则：

- `@deepseek-ai/*` 两个宿主层必须留在最前，`dsh-my-guardian` 要用它们提供的服务。
- `dsh-my-guardian` 要排在所有第三方插件之前，否则护栏醒来时插件已经在加载了。

`install.ps1` 和 agent 都会按上面的顺序自动重排，不用手改。

---

## 不包含什么

- **会话记录**（`~/.dsh/sessions`）—— 这个仓库只管插件，不管聊天历史。
- **凭据 / 登录态**（`~/.dsh/.credentials.yaml`、`.dshw-usage.json` 等）。
- **插件自己的缓存与日志**（`~/.dsh/storages/session_projcache*`、`.plugin-manager/logs`、`guardian/state.json` 的运行时事件）—— 这些是重装后会自动重建的东西，备份没意义。真正需要复现的设置都在 `cordis.patch.yml` 里。

---

## 出处

本机工作区是 `E:\DeepSeek Harness`，`desktop` profile 在 `C:\Users\ctdlb\.dsh\profiles\desktop`。别处用同一套 DSH 目录结构（`~/.dsh/...`），脚本按运行时实际路径计算，不写死盘符。
