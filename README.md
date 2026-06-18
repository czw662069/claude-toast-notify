# claude-toast-notify

> Windows Toast 通知插件 for Claude Code —— 在 Claude 结束响应或需要你注意时,右下角弹出桌面提醒。

## 功能

- 🔔 **Stop 事件**:Claude 完全结束响应、轮到你操作时弹出通知(默认文案"轮到你了")
- 🔔 **Notification 事件**:Claude 请求工具授权、空闲等待输入时弹出通知(默认文案"需要你的注意")
- 🩺 **诊断命令**:通知不弹时用 `/toast-diag` 一键自查 4 项前置条件,直接给出修复建议
- ⚙️ **可配置**:通过 `/toast-config` 命令自定义文案、应用名、单独开关每个事件
- 🔍 **失败可见**:通知被系统拦截时不再静默退出,而是把原因和修复方式打到 stderr
- 📝 **可选日志**:开启 `log.enabled` 后记录每次触发的结果,便于事后排查
- 🚫 **零依赖**:纯 Windows 系统 API,无需安装 BurntToast 等任何模块
- 🖥️ **自动注册**:首次运行自动注册 AUMID,装上即用,无需手动配置注册表

## 系统要求

- Windows 10 / 11
- Claude Code(CLI)
- **Windows PowerShell 5.1**(系统自带,即 `powershell.exe`)。**不支持 PowerShell 7 (`pwsh`)** —— WinRT 互操作在 PS7 下加载方式不同会失败。hook 已固定调用 `powershell.exe`,正常无需关心。

## 安装

### 方式一:从 GitHub marketplace 安装(推荐)

在 Claude Code 里依次执行:

```
/plugin marketplace add czw662069/claude-toast-notify
/plugin install claude-toast-notify@claude-toast-notify
```

装完**重启 Claude Code 会话**(新开一个会话即可),hook 才会被加载。

### 方式二:手动安装(本地)

1. 克隆或下载本仓库到任意目录
2. 在 `~/.claude/settings.json` 的 `extraKnownMarketplaces` 里添加:
   ```json
   "claude-toast-notify": {
     "source": { "source": "directory", "path": "C:/path/to/claude-toast-notify" }
   }
   ```
3. 在 `enabledPlugins` 里添加:
   ```json
   "claude-toast-notify@claude-toast-notify": true
   ```
4. 重启 Claude Code 会话

## 配置

运行斜杠命令:

```
/toast-config
```

会读取并展示当前配置,你可以让 Claude 帮你改文案、开关事件。

通知不弹时,运行诊断命令:

```
/toast-diag
```

会自动检查 4 项前置条件(notifier 状态 / 全局开关 / 勿扰 / AUMID 注册),并把结果翻译成可操作的修复建议。

配置文件位置:`~/.claude-toast-notify.json`,结构:

```json
{
  "appName": "Claude Code",
  "stopMessage": "轮到你了",
  "notificationMessage": "需要你的注意",
  "enabled": {
    "stop": true,
    "notification": true
  },
  "showInSettings": false,
  "log": {
    "enabled": false,
    "path": "C:/Users/<你的用户名>/.claude-toast-notify.log"
  }
}
```

| 字段 | 说明 | 默认值 |
|---|---|---|
| `appName` | 通知顶部应用名 | `Claude Code` |
| `stopMessage` | Stop 事件文案 | `轮到你了` |
| `notificationMessage` | Notification 事件文案 | `需要你的注意` |
| `enabled.stop` | 是否启用 Stop 通知 | `true` |
| `enabled.notification` | 是否启用 Notification 通知 | `true` |
| `showInSettings` | 是否在「设置→通知」显示本应用(便于手动开关/排查)。设 `true` 后可单独配置横幅/声音 | `false` |
| `log.enabled` | 是否记录每次触发的结果(时间\|Event\|Setting\|是否弹出\|原因) | `false` |
| `log.path` | 日志文件路径 | `~/.claude-toast-notify.log` |

> 配置文件不存在时使用内置默认值,插件开箱即用。`showInSettings`/`log` 为可选字段,不写即用默认值。

## 卸载

```
/plugin uninstall claude-toast-notify@claude-toast-notify
```

可选:删除 `~/.claude-toast-notify.json` 清理配置。

## 常见问题

### 通知没有弹出来

**先运行 `/toast-diag`** 一键自查。它会检查 4 项前置条件并直接告诉你该开哪个开关,而不是让你瞎猜。

如果仍要手动排查,按顺序检查:

1. **设置 → 系统 → 通知** 是否开启,以及是否允许应用发送通知
2. **重启过 Claude Code 会话**(hook 在新会话才加载)
3. `~/.claude/settings.json` 里 `enabledPlugins` 中 `claude-toast-notify@claude-toast-notify` 的值是否为 `true`
4. 全局通知开关改了**仍不弹**?Windows 会缓存用户级通知设置,以管理员身份运行 PowerShell 执行 `Restart-Service WpnService,WpnUserService*` 后再试

### 通知被系统拦截(已禁用但显示成功)

旧版本里 `$notifier.Show()` 被系统拦截时会静默 `exit 0`,用户无从知道。**新版本会在 stderr 输出禁用原因**(如"Windows 全局通知被关闭""本应用在该用户下被禁用"),并给出具体修复路径。如果你用的 Claude Code 版本不展示 hook stderr,改用 `/toast-diag` 或开启日志排查。

### 开启日志,事后排查

在 `~/.claude-toast-notify.json` 里加:

```json
"log": { "enabled": true, "path": "C:/Users/<你的用户名>/.claude-toast-notify.log" }
```

之后每次触发都会追加一行:`时间 | Event=Stop/Notification | Setting(code) | 是否弹出/原因`。出问题时把日志内容发来,省掉一整轮复现。日志不含敏感内容。

### 中文显示乱码

配置文件必须是 UTF-8 编码。用 VS Code/记事本另存为时选"UTF-8"编码。插件自带的 `notify.ps1` 已带 BOM,中文文案会正常显示。

### 两个事件都弹通知有点烦

运行 `/toast-config`,把不需要的事件设为 `false`。

### 想在「设置→通知」里单独配置本应用

默认本应用不出现在设置列表(避免污染)。把 `~/.claude-toast-notify.json` 里 `showInSettings` 设为 `true`,触发一次通知后,就能在「设置→通知」看到 "Claude Code" 并单独开关、配置横幅/声音。

### 用的是 PowerShell 7 (pwsh) 不工作

本插件仅支持 Windows PowerShell 5.1 (`powershell.exe`)。WinRT 互操作在 pwsh 7 下加载方式不同会失败。hook 已固定调用 `powershell.exe`,正常不会遇到此问题;若 `powershell` 别名被改,请恢复。

## 技术原理

- 通过 Windows Runtime 的 `ToastNotificationManager` 弹出系统 Toast(右下角滑入 + 进入通知中心)
- 用 `SetCurrentProcessExplicitAppUserModelID`(shell32.dll)为进程注册 AUMID,首次运行自动写入 `HKCU\SOFTWARE\Classes\AppUserModelId\ClaudeCode.ToastNotify`
- Hook 经 Git Bash 执行,命令用 `powershell.exe -File` + 正斜杠路径,避免引号/转义问题

## License

MIT
