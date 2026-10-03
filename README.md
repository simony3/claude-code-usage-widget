<p align="center"><img src="docs/icon.png" width="128" alt="Claude Code Usage Widget 图标"></p>

<h1 align="center">Claude Code Usage Widget</h1>

<p align="center">把 Claude Code CLI 的使用统计放到 macOS 桌面上的原生小组件</p>

<p align="center">中文 · <a href="README.en.md">English</a></p>

<p align="center"><img src="docs/screenshots/extra-large.png" width="720" alt="超大号小组件"></p>

## 它能做什么

一个 WidgetKit 桌面小组件，布局参考 Claude 桌面版的用量面板，数据全部来自本机 `~/.claude/projects` 里的 Claude Code CLI 会话记录，不联网、不上传。

- **概览**：会话数、Token（输入+输出）、全部 Token（含缓存）、活跃天数、高峰时段、最常用模型
- **模型**：按模型拆开输入 / 输出 / 缓存读 / 缓存写四类 token
- **时间范围**：全部 / 30 天 / 7 天，点一下切换
- **热力图**：每格一天，颜色越深当天越活跃
- **某天详情**：点热力图的格子进入当天详情页，显示全部 token、输入 / 输出 / 缓存读 / 缓存写、你发的消息、Claude 回复、会话数、高峰时段和各模型用量；左上角「返回」回到主界面，右上角 ◀ ▶ 前后切换
- **四种尺寸**：小、中、大、超大

| 中号 | 中号 · 某天详情 |
|---|---|
| <img src="docs/screenshots/medium.png" width="360"> | <img src="docs/screenshots/medium-day.png" width="360"> |

| 大号 | 大号 · 模型页 | 小号 |
|---|---|---|
| <img src="docs/screenshots/large.png" width="260"> | <img src="docs/screenshots/large-models.png" width="260"> | <img src="docs/screenshots/small.png" width="140"> |

<p align="center"><img src="docs/screenshots/extra-large-day.png" width="720" alt="超大号 · 某天详情"></p>

> 截图是实色渲染；放在桌面上时 macOS 会给小组件加上玻璃 / 淡色效果。

## 统计口径

- **只算 Claude Code CLI**：Claude 桌面版的 Code 功能也会往 `~/.claude/projects` 写记录（`entrypoint` 为 `claude-desktop`），这些会被排除。
- **按回复去重**：同一次模型回复会按内容块拆成多行写入记录，每行都带同一份 usage（实测平均重复约 2.2 次）。这里按 `message.id` 去重，所以数字会比直接累加的小。
- **Token（输入+输出）**：不含缓存。**全部 Token**：输入 + 输出 + 缓存读 + 缓存写，几乎都是缓存读取。
- **会话**：有过对话的会话文件数（子 agent 的记录算 token，不单独算会话）。
- **活跃天数 / 高峰时段 / 热力图**：按本地时区，以你发的话 + 模型回复计数。
- 统计逻辑用独立的 Python 脚本逐项对账过。

## 从源码安装

需要 macOS 15+、Xcode、[XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。

```bash
git clone https://github.com/simony3/claude-code-usage-widget.git
cd claude-code-usage-widget
./build.sh install
```

默认用 ad-hoc 签名，不需要证书。装好后在桌面右键 →「编辑小组件」→ 搜索「Claude」，把「Claude Code 用量小组件」拖到桌面。

改了代码重新跑 `./build.sh install` 即可。

## 工作原理

```
~/.claude/projects/**/*.jsonl
        │  每 10 分钟扫描，只解析有变化的文件（增量缓存）
        ▼
ClaudeUsage.app（后台常驻、开机自启、无窗口）
        │  写 ~/Library/Application Support/ClaudeUsage/snapshot.json
        ▼
小组件扩展（沙盒，只读这一个目录）──► 桌面
```

- 不用 App Group：没有描述文件时 App Group 不可用，所以 App 写普通目录，小组件通过沙盒只读例外读取。
- 调试：`ClaudeUsage --dump` 打印统计结果，`ClaudeUsage --render <目录>` 渲染各尺寸截图。

## 已知限制

- Claude Code 默认只保留 30 天的会话记录，所以「全部」实际只覆盖约一个月。想保留更久，在 `~/.claude/settings.json` 里设置 `cleanupPeriodDays`。
- 小组件刷新时间由系统决定，数据最多晚十几分钟。
- 桌面小组件收不到键盘事件，所以切换日期用 ◀ ▶ 按钮而不是方向键。
- 小号的格子太小，点热力图任意位置会先打开今天的详情，再用箭头切换。

## 声明

个人开源项目，与 Anthropic 无关，不是官方产品。Claude 是 Anthropic 的商标。
