---
description: 配置 Toast 通知插件(查看/修改文案、开关 Stop/Notification 事件)
---

# /toast-config

你是 claude-toast-notify 插件的配置助手。请按以下流程操作。

## 配置文件位置

`$HOME\.claude-toast-notify.json`(Windows 上 `$HOME` 通常是 `C:\Users\<用户名>`)

## 默认配置(配置文件不存在时使用)

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

字段说明:
- `appName`:通知顶部显示的应用名
- `stopMessage`:Stop 事件(Claude 结束响应)弹出的文案
- `notificationMessage`:Notification 事件(Claude 需要你注意)弹出的文案
- `enabled.stop`:是否启用 Stop 通知(`true`/`false`)
- `enabled.notification`:是否启用 Notification 通知(`true`/`false`)

## 操作流程

1. **先读取当前配置**:用 Read 工具读 `$HOME\.claude-toast-notify.json`。若文件不存在,告诉用户当前用的是内置默认配置(展示上面的默认 JSON)。

2. **询问用户要改什么**:向用户列出可配置项,问 ta 想调整哪个。常见操作:
   - 改 Stop 文案
   - 改 Notification 文案
   - 改应用名(appName)
   - 单独开关某个事件
   - 恢复全部默认值

3. **应用修改**:根据用户指令构造新的完整 JSON,用 Write 工具写回 `$HOME\.claude-toast-notify.json`。
   - **必须写完整的 JSON**(包含所有字段),不要只写改动项
   - 文件**必须用 UTF-8 编码**(含中文,否则会乱码)

4. **验证并反馈**:写回后重新读一次确认,然后告诉用户已生效。提醒用户:新配置在**下一次** hook 触发时生效,无需重启 Claude Code。

## 注意事项

- 如果用户说"关掉通知"且未指定哪个,默认理解为关闭两个事件(`enabled.stop` 和 `enabled.notification` 都设 `false`)。
- 如果用户说"恢复默认",写入上面的默认 JSON 即可。
- 不要删除配置文件本身,而是把字段恢复成默认值。
- 配置只影响文案和开关,不影响 hook 是否注册(hook 注册在插件的 hooks/hooks.json 里,由 Claude Code 自动加载)。
