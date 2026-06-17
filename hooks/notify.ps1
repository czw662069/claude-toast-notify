<#
.SYNOPSIS
    Claude Code Toast 通知 hook 脚本。

.DESCRIPTION
    被 claude-toast-notify 插件的 hooks 调用。根据 -Event 参数(Stop / Notification)
    从用户配置文件读取对应文案,弹出 Windows Toast 通知。

    配置文件位置:$HOME\.claude-toast-notify.json
    不存在或字段缺失时回退到内置默认值。

    纯系统 API,无需安装任何模块。首次运行自动注册 AUMID(别人机器也能直接用)。

.PARAMETER Event
    触发的事件名:Stop 或 Notification。

.EXAMPLE
    powershell -File notify.ps1 -Event Stop
    powershell -File notify.ps1 -Event Notification
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Stop", "Notification")]
    [string]$Event
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# 1) 读取用户配置(不存在则用默认值)
# ---------------------------------------------------------------------------
$ConfigPath = Join-Path $HOME ".claude-toast-notify.json"

# 默认值
$defaults = @{
    appName              = "Claude Code"
    stopMessage          = "轮到你了"
    notificationMessage  = "需要你的注意"
    enabled = @{
        stop          = $true
        notification  = $true
    }
}

$appName             = $defaults.appName
$stopMessage         = $defaults.stopMessage
$notificationMessage = $defaults.notificationMessage
$stopEnabled         = $defaults.enabled.stop
$notifEnabled        = $defaults.enabled.notification

if (Test-Path -LiteralPath $ConfigPath) {
    try {
        $cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.appName)             { $appName             = [string]$cfg.appName }
        if ($cfg.stopMessage)         { $stopMessage         = [string]$cfg.stopMessage }
        if ($cfg.notificationMessage) { $notificationMessage = [string]$cfg.notificationMessage }
        if ($null -ne $cfg.enabled.stop)         { $stopEnabled  = [bool]$cfg.enabled.stop }
        if ($null -ne $cfg.enabled.notification) { $notifEnabled = [bool]$cfg.enabled.notification }
    } catch {
        # 配置文件损坏就回退默认值,不让通知失败阻塞 Claude
    }
}

# ---------------------------------------------------------------------------
# 2) 根据事件选文案;该事件被禁用则静默退出
# ---------------------------------------------------------------------------
if ($Event -eq "Stop") {
    if (-not $stopEnabled) { exit 0 }
    $message = $stopMessage
} else {
    if (-not $notifEnabled) { exit 0 }
    $message = $notificationMessage
}

# ---------------------------------------------------------------------------
# 3) 为当前进程设置 AUMID + 注册表登记(桌面程序发 Toast 的关键步骤)
#    AUMID 对所有用户固定,首次运行自动注册,别人机器也能直接用。
# ---------------------------------------------------------------------------
$AppId = "ClaudeCode.ToastNotify"

if (-not ("AppUserModelHelper" -as [type])) {
    $cs = '
    using System;
    using System.Runtime.InteropServices;
    public static class AppUserModelHelper {
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        public static extern void SetCurrentProcessExplicitAppUserModelID(string appID);
    }
    '
    Add-Type -TypeDefinition $cs -Language CSharp
}
[AppUserModelHelper]::SetCurrentProcessExplicitAppUserModelID($AppId)

$regPath = "HKCU:\SOFTWARE\Classes\AppUserModelId\" + $AppId
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}
$null = New-ItemProperty -Path $regPath -Name "DisplayName" -Value $appName -PropertyType String -Force
$null = New-ItemProperty -Path $regPath -Name "ShowInSettings" -Value 0 -PropertyType DWord -Force

# ---------------------------------------------------------------------------
# 4) 加载 WinRT 类型
# ---------------------------------------------------------------------------
$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
$null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime]

# ---------------------------------------------------------------------------
# 5) 构造 Toast XML(无标题,仅应用名 + 正文)
# ---------------------------------------------------------------------------
$escapedApp = [System.Security.SecurityElement]::Escape($appName)
$escapedMsg = [System.Security.SecurityElement]::Escape($message)

$template = @"
<toast>
  <visual>
    <binding template="ToastGeneric">
      <text>$escapedApp</text>
      <text>$escapedMsg</text>
    </binding>
  </visual>
  <audio src="ms-winsoundevent:Notification.Default"/>
</toast>
"@

# ---------------------------------------------------------------------------
# 6) 发送
# ---------------------------------------------------------------------------
$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)

$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
$notifier.Show($toast)

exit 0
