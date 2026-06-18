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
# 0) 防御:pwsh 7 (Core) 下 WinRT 互操作加载方式不同,可能直接失败。
#    本插件仅支持 Windows PowerShell 5.1。hooks.json 已固定用 powershell.exe,
#    此处为兜底(防止 powershell 别名被指向 pwsh)。
# ---------------------------------------------------------------------------
if ($PSVersionTable.PSEdition -eq "Core") {
    [Console]::Error.WriteLine("[claude-toast-notify] 检测到 PowerShell 7 (Core)。本插件依赖 WinRT 互操作,仅支持 Windows PowerShell 5.1。请用 powershell.exe 而非 pwsh 触发 hook。")
    exit 0
}

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
    showInSettings       = $false
    log = @{
        enabled = $false
        path    = (Join-Path $HOME ".claude-toast-notify.log")
    }
}

$appName             = $defaults.appName
$stopMessage         = $defaults.stopMessage
$notificationMessage = $defaults.notificationMessage
$stopEnabled         = $defaults.enabled.stop
$notifEnabled        = $defaults.enabled.notification
$showInSettings      = $defaults.showInSettings
$logEnabled          = $defaults.log.enabled
$logPath             = $defaults.log.path

if (Test-Path -LiteralPath $ConfigPath) {
    try {
        $cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.appName)             { $appName             = [string]$cfg.appName }
        if ($cfg.stopMessage)         { $stopMessage         = [string]$cfg.stopMessage }
        if ($cfg.notificationMessage) { $notificationMessage = [string]$cfg.notificationMessage }
        if ($null -ne $cfg.enabled.stop)         { $stopEnabled  = [bool]$cfg.enabled.stop }
        if ($null -ne $cfg.enabled.notification) { $notifEnabled = [bool]$cfg.enabled.notification }
        if ($null -ne $cfg.showInSettings)       { $showInSettings = [bool]$cfg.showInSettings }
        if ($null -ne $cfg.log) {
            if ($null -ne $cfg.log.enabled) { $logEnabled = [bool]$cfg.log.enabled }
            if ($cfg.log.path)              { $logPath    = [string]$cfg.log.path }
        }
    } catch {
        # 配置文件损坏就回退默认值,不让通知失败阻塞 Claude
    }
}

# ---------------------------------------------------------------------------
# 1.5) 可选日志:每次触发追加一行,便于事后排查"那次为什么没弹"
#      记录字段:时间 | Event | Setting(code) | 是否调用 Show | exit 原因
#      不写敏感内容(本插件不涉及)。默认关闭,需配置 log.enabled=true。
# ---------------------------------------------------------------------------
function Write-LogLine {
    param([string]$Path, [string]$Event, [string]$Setting, [string]$Note)
    try {
        $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $line = "$ts | Event=$Event | Setting=$Setting | $Note"
        Add-Content -LiteralPath $Path -Value $line -Encoding UTF8
    } catch {
        # 日志失败绝不影响通知流程
    }
}

# ---------------------------------------------------------------------------
# 2) 根据事件选文案;该事件被禁用则静默退出
# ---------------------------------------------------------------------------
if ($Event -eq "Stop") {
    if (-not $stopEnabled) {
        if ($logEnabled) { Write-LogLine $logPath $Event "-" "skip(event disabled)" }
        exit 0
    }
    $message = $stopMessage
} else {
    if (-not $notifEnabled) {
        if ($logEnabled) { Write-LogLine $logPath $Event "-" "skip(event disabled)" }
        exit 0
    }
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
# ShowInSettings:默认 0(不污染设置列表);配置 showInSettings=true 时写 1,
# 用户即可在「设置→通知」单独开关/配置本应用(出问题时便于排查)。
$null = New-ItemProperty -Path $regPath -Name "ShowInSettings" -Value ([int][bool]$showInSettings) -PropertyType DWord -Force

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
#    核心:Show() 前检查 $notifier.Setting。被系统禁用时 Show() 不抛错、
#    照常返回,但通知不会弹出 —— 这是"静默失败"的根因。
#    这里把禁用原因翻译成中文修复指引打到 stderr(用户可见),
#    同时仍 exit 0,绝不阻塞 Claude 的 Stop/Notification。
# ---------------------------------------------------------------------------
$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($template)

$toast = New-Object Windows.UI.Notifications.ToastNotification $xml
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)

# Setting 枚举:0=Enabled 1=DisabledForApplication 2=DisabledForUser
#              3=DisabledByGroupPolicy 4=DisabledByManifest
$settingCode = -1
try { $settingCode = [int]$notifier.Setting } catch {}

if ($settingCode -ne 0) {
    $hint = switch ($settingCode) {
        2 { "Windows 全局通知被关闭。打开:设置→系统→通知→开启『获取来自应用和其他发送者的通知』。改完若仍不弹,以管理员身份运行 PowerShell 执行:`Restart-Service WpnService,WpnUserService*`(改注册表后通知子系统缓存了设置,需重启推送服务才生效)。" }
        1 { "本应用(ClaudeCode.ToastNotify)在该用户下被禁用。打开:设置→系统→通知,在应用列表里找到本应用并开启。" }
        3 { "通知被组策略禁用(公司机器常见),需联系管理员。" }
        4 { "通知被应用清单禁用。" }
        default { "通知被系统禁用(Setting 代码 $settingCode)。" }
    }
    [Console]::Error.WriteLine("[claude-toast-notify] 通知未弹出:$hint")
    [Console]::Error.WriteLine("[claude-toast-notify] 提示:运行 /toast-diag 可一键自查 4 项通知前置条件。")
    if ($logEnabled) { Write-LogLine $logPath $Event "$settingCode" "skip(notifier disabled)" }
    exit 0
}

try {
    $notifier.Show($toast)
    if ($logEnabled) { Write-LogLine $logPath $Event "0" "shown" }
} catch {
    [Console]::Error.WriteLine("[claude-toast-notify] Show() 抛错:$($_.Exception.Message)")
    if ($logEnabled) { Write-LogLine $logPath $Event "0" "error: $($_.Exception.Message)" }
}

exit 0
