# DSH 用户级规则

本文件是 `$DSH_HOME/AGENTS.md`（本机为 `%USERPROFILE%\.dsh\AGENTS.md`），对所有工作区、所有会话生效。工作区自己的 `AGENTS.md` 优先级更高，冲突时以工作区那份和用户当前指令为准。

> **这份规则住在哪**（用户 2026-10-24 定）：**生效的就是本文件** `%USERPROFILE%\.dsh\AGENTS.md`，DSH 启动时读它；备份副本在 `ctdlb/dsh-plugins` 仓库根目录的 `AGENTS.md`（换机装回用）。改法：直接改本文件 → 把同一内容更新到仓库那份 → 推。`ff14-plugin-workspace` 仓库里**不再保存用户级规则副本**（原来的 `config/AGENTS.user.md` 与 `tools/sync-user-agents.ps1` 已删除），也没有同步脚本。
> **只放 DSH 相关规则**（用户 2026-10-24 定）：本文件只写「DSH 插件备份库」「本地 TTS 配音」这类与本机 DSH 环境有关的内容；**FF14 插件开发的通用经验不放这里**，统一放在工作区自己的 `AGENTS.md` 的「跨插件通用经验」一节（只在那个工作区开对话时才加载，所以做插件必须在该工作区开会话）。

## DSH 插件备份库

- 仓库：`ctdlb/dsh-plugins`（公开）—— `https://github.com/ctdlb/dsh-plugins`。**只备份插件本体，不备份任何配置。**
- 存的是 `plugins.json`（全部包名 + 锁定版本 + `bundles` 加载顺序，具体数量与顺序以该文件为准）和 `install.ps1` 一键恢复脚本，另有 `tts/` 三个配音小工具（`install.ps1` 会把它们复制到 `~/.dsh`）。仓库里没有 `cordis.patch.yml`、`.dsh-market/state.json`、`pnpm-workspace.yaml`，也不该有。
- 为什么不备份配置：旧配置搬到新机器会把环境配坏 —— 已卸载插件的开关、过期的权限预设、不再适用的 pnpm 排除项都会写回去。插件装好后按当时的需要重新设一遍更安全。
- 本机 profile：`%USERPROFILE%\.dsh\profiles\desktop`。仓库本地副本：工作区下的 `.dsh-plugins`（本机是 `E:\DeepSeek Harness\.dsh-plugins`）。
- **远端仓库是唯一真源（用户 2026-10-23 定）**：本地副本只是工作拷贝。两者不一致时，一律用远端覆盖本地（`https://raw.githubusercontent.com/ctdlb/dsh-plugins/main/...`），不要拿本地去覆盖远端；覆盖前先备份被改的那个文件（`.bak`）。唯一例外是用户明确说「同步插件库」——那一次才把本机 profile 的状态写进远端，本地副本随之更新。
- 用户说「**装回插件**」时：读 `plugins.json` → `dsh plugin --profile desktop add <包@版本…>` → 按清单把 `bundles` 顺序写回 profile 的 `package.json` → 校验 `node_modules` → 提示完全退出 DSH 再启动。**不要碰任何配置文件。**
- 用户说「**同步插件库**」时：读 profile 的 `package.json`，重写仓库里的 `plugins.json`（`dependencies` 全量 + `bundles` 原顺序），推上去。配置文件一律不进仓库。
- 推送走 `api.github.com`（Git Data API 一次原子提交），令牌从 Windows 凭据管理器 `git:https://ctdlb@github.com` 读，**不得写进文件、日志或提交内容**。
- 新装插件、升级版本后要同步；仓库不含配置、会话记录、凭据与缓存。
- 新电脑第一次用：由用户带上链接说一句「装回插件」，之后把这条规则写进新机器。

## 本地 TTS 配音（answer-me-with-html）

- **默认不生成配音，也不拉起后台服务**。渲染视频用无音模式（`--voice off`）；只有用户明确说要配音时才启用微软 TTS。
- 要配音时按需起停，**渲染完立刻关掉**，不常驻（用户介意常驻进程与外挂误判）。**起停由 agent 自己做，用户不操作任何文件**——用户只说「要配音」，agent 负责 `start → 渲染 → stop` 全流程；即使渲染报错，收尾那一步也必须执行，不能留下监听进程。
- **首选脚本**（`%USERPROFILE%\.dsh\tts-start.ps1` / `tts-stop.ps1`，已加入 360 信任区；2026-10-21 360 曾把 `tts-start.ps1` 报成「恶意行为监控 / 木马病毒」——误报，原因是「P/Invoke 读凭据 + `Add-Type` 编译 + 隐藏窗口 + 本地监听」凑齐了窃密木马的行为特征）：
  1. `powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.dsh\tts-start.ps1"` —— 读凭据管理器 `TextToTalk_AccessKeys_AzureCognitiveServices`，起 `tts-shim.mjs` 于 `http://127.0.0.1:18321`（默认音色 `zh-CN-Xiaoxiao:DragonHDFlashLatestNeural`），自带健康检查；
  2. 渲染：设 `AM_TTS_URL=http://127.0.0.1:18321`、`AM_TTS_MODEL=azure`、`AM_TTS_VOICE=<音色 ID>`，用 `Start-Process -Wait` 跑 `am.mjs video --voice local --no-open <草稿>`；`am` 不在 PATH，脚本固定在 `<profile>\node_modules\dsh-answer-me-with-html\skills\answer-me-with-html\scripts\am.mjs`（本机 `<profile>` = `%USERPROFILE%\.dsh\profiles\desktop`），要用 DSH 自带的 Electron 运行时当 node 跑：设 `ELECTRON_RUN_AS_NODE=1` 后执行 DSH 主程序（`DeepSeek Harness.exe`，路径以本机安装位置为准）并传该脚本；`Start-Process` 里脚本路径和草稿路径**都不能带空格**（会被拆开，报 `Cannot read the draft: ENOENT ... 'E:\DeepSeek'`），草稿放 `%USERPROFILE%\.dsh\draft-*.md`；
  3. 收尾：`powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\.dsh\tts-stop.ps1"`，再确认 18321 端口已释放。
- **回退方案**（脚本再次被杀、或在新机器上）：同一段 pwsh 里 P/Invoke `CredRead` 读凭据 → 设 `AZKEY`/`AZREGION`/`AZDEFAULTVOICE` → `Start-Process` 起 `tts-shim.mjs`（须在已设 `ELECTRON_RUN_AS_NODE=1` 的进程里启动）→ 渲完后按 `Get-NetTCPConnection -LocalPort 18321` 取 pid 再 `Stop-Process -Force`。
- `am` 只认 ElevenLabs 或「本地 OpenAI 兼容 TTS」，不认 Azure；`tts-shim.mjs` 就是这层转换（对外 `POST /v1/audio/speech`，返回 24 kHz 单声道 PCM WAV）。`--voice system` 只在 macOS/Linux 有实现，Windows 上等于没有声音。
- 同一段文字按文本哈希命中 `%USERPROFILE%\.answer-me-with-html\cache\tts` 里的旧音频，**换音色或改念法前必须清空该目录**，否则听到的还是旧音频。
- **号码要一字一顿**：Azure 会把 `999` 念成「九百九十九」、`120` 念成「一百二十」。起服务前设 `AM_TTS_SUBS`（JSON，「原文 → 念法」），例如 `$env:AM_TTS_SUBS='{"999":"九九九","120":"一二零","110":"一一零","119":"一一九"}'`；草稿里照常写阿拉伯数字，字幕不受影响。`tts-start.ps1` 会把这个变量传给 shim，`/health` 的 `subs` 字段显示生效条数。
- **新机器要用配音，先补凭据**：密钥不在仓库里。打开「控制面板 → 凭据管理器 → Windows 凭据 → 添加普通凭据」，目标名填 `TextToTalk_AccessKeys_AzureCognitiveServices`、用户名填区域（本机用 `eastasia`）、密码填 32 位十六进制的 Azure 语音订阅密钥；`tts-start.ps1` 就是按这个目标名去读的。
- 密钥只在进程环境变量（`AZKEY`/`AZREGION`）里，任何脚本与文档都不得写入密钥本身。
- 音色都取自 `GET https://<region>.tts.speech.microsoft.com/cognitiveservices/voices/list`；zh-CN 共 81 个，其中晓晓系 5 个（标准 / 高清一代 `zh-CN-Xiaoxiao:DragonHDFlashLatestNeural` / 高清二代 `zh-CN-Xiaoxiao2:DragonHDFlashLatestNeural` / 多语种 / 方言）。
