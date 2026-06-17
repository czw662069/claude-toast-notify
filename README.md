# claude-toast-notify

> Windows Toast 通知插件 for Claude Code —— 在 Claude 结束响应或需要你注意时,右下角弹出桌面提醒。

## 功能

- 🔔 **Stop 事件**:Claude 完全结束响应、轮到你操作时弹出通知(默认文案"轮到你了")
- 🔔 **Notification 事件**:Claude 请求工具授权、空闲等待输入时弹出通知(默认文案"需要你的注意")
- ⚙️ **可配置**:通过 `/toast-config` 命令自定义文案、应用名、单独开关每个事件
- 🚫 **零依赖**:纯 Windows 系统 API,无需安装 BurntToast 等任何模块
- 🖥️ **自动注册**:首次运行自动注册 AUMID,装上即用,无需手动配置注册表

## 系统要求

- Windows 10 / 11
- Claude Code(CLI)
- PowerShell(系统自带)

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

配置文件位置:`~/.claude-toast-notify.json`,结构:

```json
{
  "appName": "Claude Code",
  "stopMessage": "轮到你了",
  "notificationMessage": "需要你的注意",
  "enabled": {
    "stop": true,
    "notification": true
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

> 配置文件不存在时使用内置默认值,插件开箱即用。

## 卸载

```
/plugin uninstall claude-toast-notify@claude-toast-notify
```

可选:删除 `~/.claude-toast-notify.json` 清理配置。

## 常见问题

### 通知没有弹出来

1. 检查 **设置 → 系统 → 通知** 是否开启,以及是否允许 PowerShell 发通知
2. 确认**重启过 Claude Code 会话**(hook 在新会话才加载)
3. 运行 `settings.json` 里 `enabledPlugins` 中插件值是否为 `true`

### 中文显示乱码

配置文件必须是 UTF-8 编码。用 VS Code/记事本另存为时选"UTF-8"编码。插件自带的 `notify.ps1` 已带 BOM,中文文案会正常显示。

### 两个事件都弹通知有点烦

运行 `/toast-config`,把不需要的事件设为 `false`。

## 技术原理

- 通过 Windows Runtime 的 `ToastNotificationManager` 弹出系统 Toast(右下角滑入 + 进入通知中心)
- 用 `SetCurrentProcessExplicitAppUserModelID`(shell32.dll)为进程注册 AUMID,首次运行自动写入 `HKCU\SOFTWARE\Classes\AppUserModelId\ClaudeCode.ToastNotify`
- Hook 经 Git Bash 执行,命令用 `powershell.exe -File` + 正斜杠路径,避免引号/转义问题

## License

MIT
