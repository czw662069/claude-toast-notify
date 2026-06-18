---
description: 一键诊断 Toast 通知为什么不弹(检查 Setting/全局开关/勿扰/AUMID 注册)
---

# /toast-diag

你是 claude-toast-notify 插件的诊断助手。用户报告"通知没弹"或想自查通知前置条件时,跑以下 4 项检查,把原始结果翻译成用户能懂的操作建议。

## 执行步骤

用 Bash 工具运行下面这段 PowerShell(只读检查,不改任何系统设置):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
$ErrorActionPreference = 'Continue'
$AppId = 'ClaudeCode.ToastNotify'

# --- 1) notifier.Setting(最关键):0=Enabled 1=DisabledForApplication 2=DisabledForUser 3=DisabledByGroupPolicy 4=DisabledByManifest ---
if (-not ('AppUserModelHelper' -as [type])) {
    Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public static class AppUserModelHelper{[DllImport(\"shell32.dll\",CharSet=CharSet.Unicode)]public static extern void SetCurrentProcessExplicitAppUserModelID(string appID);}' -Language CSharp
}
[AppUserModelHelper]::SetCurrentProcessExplicitAppUserModelID($AppId)
$null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
$code = try { [int]$notifier.Setting } catch { -1 }
Write-Output ('1.notifier.Setting = ' + $code)

# --- 2) 全局 ToastEnabled(0=关 1=开) ---
$te = try { (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications' -Name ToastEnabled -ErrorAction Stop).ToastEnabled } catch { 'N/A' }
Write-Output ('2.ToastEnabled(global) = ' + $te)

# --- 3) FocusAssist / 勿扰(0=关 1=仅优先 2=开) ---
$fa = try { (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings' -Name NOC_GLOBAL_SETTING_TOASTS_ENABLED -ErrorAction Stop).NOC_GLOBAL_SETTING_TOASTS_ENABLED } catch { 'N/A' }
Write-Output ('3.ToastsEnabledSetting = ' + $fa)

# --- 4) AUMID 注册是否存在 + ShowInSettings 值 ---
$regPath = 'HKCU:\SOFTWARE\Classes\AppUserModelId\' + $AppId
if (Test-Path $regPath) {
    $sis = try { (Get-ItemProperty $regPath -Name ShowInSettings -ErrorAction Stop).ShowInSettings } catch { 'unset' }
    $dn = try { (Get-ItemProperty $regPath -Name DisplayName -ErrorAction Stop).DisplayName } catch { 'unset' }
    Write-Output ('4.AUMID registered = yes (DisplayName=' + $dn + ', ShowInSettings=' + $sis + ')')
} else {
    Write-Output '4.AUMID registered = NO (尚未注册,正常安装并触发过一次后会自动写入)'
}
"
```

## 结果解读规则

拿到 4 行输出后,按下表给用户**结论 + 具体修复动作**(不要只甩原始数字):

| 检查项 | 正常值 | 异常时的修复建议 |
|---|---|---|
| **1. notifier.Setting** | `0` | 非 0 即问题根源。`2`→全局通知关了:设置→系统→通知→开启,改完以管理员 PowerShell 跑 `Restart-Service WpnService,WpnUserService*`;`1`→本应用被禁用:设置→系统→通知里开启本应用;`3`→组策略禁用,找管理员;`4`→清单禁用 |
| **2. ToastEnabled** | `1` | `0`→全局通知关闭。设置→系统→通知→开启『获取来自应用和其他发送者的通知』 |
| **3. ToastsEnabledSetting** | `1` | `0`→通知被关闭(勿扰/专注辅助可能也会压住) |
| **4. AUMID registered** | `yes` | `NO`→说明从未成功触发过。让用户在 Claude Code 里随便产生一次 Stop 事件(等 Claude 回复完),或检查插件是否启用、是否重启过会话 |

## 输出格式

1. 先用一句话总结**最可能的原因**(优先看第 1 项,它最权威)
2. 再列出具体要做的操作步骤(按顺序)
3. 如果 4 项全正常但仍不弹,提示用户:
   - 确认重启过 Claude Code 会话(hook 在新会话才加载)
   - 确认 `enabledPlugins` 里插件值为 `true`
   - 开启可选日志(配置 `log.enabled=true`)后再触发一次,把日志内容发来排查

## 注意事项

- 此命令**只读**,绝不修改注册表、不重启服务、不改配置
- 第 1 项的枚举值是本次排查的核心,**务必翻译成中文**,别让用户面对 `2` 这种数字
- 如果用户的 `$HOME\.claude-toast-notify.json` 里 `enabled.stop`/`enabled.notification` 都是 `false`,也会导致不弹 —— 顺手提一句让用户检查配置
