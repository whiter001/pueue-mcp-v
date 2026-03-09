# pueue-mcp-v

这个仓库是原版 [pueue-mcp](https://github.com/whiter001/pueue-mcp) 项目的 **V 语言** 实现。

本项目为 [Pueue](https://github.com/Nukesor/pueue) 提供 MCP（Model Context Protocol）工具支持。Pueue 是一个命令行工具，用于管理带有队列、组和依赖关系的长期运行的 shell 命令。

Go 语言的参考代码位于 `../pueue-mcp`（在当前工作区之外）；本项目使用 V 语言复刻了其功能。

## 项目结构

```
.
├── main.v              # 入口点
├── core/               # 核心库代码
│   ├── mcp.v           # MCP 服务器实现
│   ├── pueue.v         # CLI 客户端封装
│   └── pueue_test.v    # 单元测试
├── tests/              # 集成测试（Python + Bun 真实测试）
├── build.sh            # 构建辅助脚本
├── fmt.sh              # 代码格式化脚本
└── v.mod               # V 模块定义
```

- `main.v` – 入口点，负责初始化 Pueue 客户端并通过 stdio 启动 MCP 服务器（位于项目根目录）。
- `core/` – 包含核心逻辑的目录：
  - `pueue.v` – CLI 客户端，封装了对 `pueue` 命令的调用并解析其 JSON 输出。
  - `mcp.v` – 简化的 MCP 服务器框架，支持工具注册和请求分发。
  - `pueue_test.v` – 核心功能的单元测试。
- `v.mod` – V 编译器的模块定义文件。

> `pueue.v` 和 `mcp.v` 中的 API 签名特意保持与 Go 源代码相似，以便于比较。

> 当前的服务器实现是一个简单的基于 stdio 的 JSON 分发器。它模仿了 mark3labs/mcp-go 的行为，但不依赖外部 MCP 库。当有更完整的实现可用时，可以随意替换它。

## 快速开始

1. 安装 [Vlang](https://vlang.io/)。
2. 克隆本仓库，并确保你的 `PATH` 中有可用的 `pueue` 二进制文件。
3. 构建并运行（在项目根目录下）：

   ```sh
   # 运行测试
   v test core

   # 构建可执行文件
   v -o pueue-mcp main.v

   # 或使用辅助脚本
   ./build.sh        # 测试 + 构建
   ./fmt.sh          # 格式化代码和文档

   # 直接运行而不编译
   v run main.v
   ```

### 辅助脚本

- **`build.sh`**: 运行测试并构建二进制文件。

  ```sh
  ./build.sh        # 测试 + 构建
  ./build.sh clean # 清理二进制文件
  ```

- **`fmt.sh`**: 格式化 V 源代码和 Markdown 文档。
  ```sh
  ./fmt.sh
  ```

## 测试

```sh
# 单元测试（V 语言）
v test core

# 集成测试（Python）
python3 tests/test_mcp_integration.py

# 真实端到端测试（Bun）
bun run test:real

# 或通过构建脚本运行所有测试
./build.sh
```

测试套件覆盖所有 14 个 MCP 工具及各种参数组合。

其中 `bun run test:real` 会：

- 临时编译一个测试专用的 `pueue-mcp` 二进制
- 通过真实 JSON-RPC 请求与 MCP 服务器交互
- 调用真实 `pueue` / `pueued` 守护进程
- 验证任务添加、等待、日志读取、状态解析等真实功能

### 任务管理

- **`pueue_add`**: 提交并排队执行新命令。
  - 参数：`command`（必需）、`label`、`group`、`delay`、`working_directory`、`immediate`、`stashed`、`priority`、`after`、`raw_args`
  - **延时/定时执行**：使用 `delay` 参数可以调度任务在稍后执行。
    - **相对时间**：`"3h"`（3 小时）、`"10min"`（10 分钟）、`"+60"`（60 秒后）
    - **绝对时间**：`"2024-12-31T23:59:59"`、`"18:00"`、`"5pm"`
    - **基于日期**：`"tomorrow"`（明天）、`"monday"`（周一）、`"wednesday 10:30pm"`（周三晚上 10:30）、`"next friday"`（下周五）
  - **顺序执行**：使用 `after` 参数指定前置任务 ID，实现任务依赖
- **`pueue_enqueue`**: 将暂存的任务加入队列，或为其设置/更新延时定时器。
  - 参数：`ids`、`all`、`group`、`delay`
  - 用于为已暂存的任务添加延时
- **`pueue_remove`**: 从队列中移除任务。
- **`pueue_restart`**: 重新启动已完成或失败的任务。
- **`pueue_kill`**: 强制停止正在运行的任务。
- **`pueue_wait`**: 等待任务完成。

### 执行控制

- **`pueue_pause`**: 暂停任务或组。
- **`pueue_resume`**: 恢复被暂停的任务或组。
- **`pueue_start`**: 启动暂停的任务。

### 状态与日志

- **`pueue_status`**: 获取守护进程的当前状态（包括组和任务）。
- **`pueue_log`**: 查看指定任务的日志输出。

### 队列与清理

- **`pueue_clean`**: 清理已完成的任务列表。
- **`pueue_group_add`**: 添加新组。
- **`pueue_group_remove`**: 删除组。
- **`pueue_parallel`**: 设置组的并行任务数。

## 在 MCP 客户端（如 Claude Desktop）中使用

配置您的 MCP 客户端以运行 `pueue-mcp` 二进制文件。服务器使用标准输入/输出进行通信。

Claude Desktop 配置示例 (`claude_desktop_config.json`)：

```json
{
  "mcpServers": {
    "pueue": {
      "command": "/path/to/pueue-mcp-v/pueue-mcp",
      "args": []
    }
  }
}
```

连接后，您可以要求 Claude：

- "查看当前的 pueue 状态"
- "帮我后台执行 `v build` 命令，并打上 `build` 标签"
- "查看任务 ID 为 5 的最后 20 行日志"
- "清理所有成功的 pueue 任务"
- "安排一个备份脚本在明天凌晨 2 点运行"
- "在另一个任务完成后执行某个任务"

## 定时与延时任务

`pueue_add` 和 `pueue_enqueue` 工具通过 `delay` 参数支持灵活的调度功能：

### 延时格式示例

| 格式 | 示例 | 说明 |
|------|------|------|
| 相对时间 | `"3h"`, `"10min"`, `"+60"` | 3 小时后、10 分钟后、60 秒后执行 |
| 绝对时间 | `"2024-12-31T23:59:59"`, `"18:00"`, `"5pm"` | 在指定时间执行 |
| 基于日期 | `"tomorrow"`, `"monday"`, `"next friday"` | 在指定日期执行 |
| 组合 | `"wednesday 10:30pm"`, `"tomorrow 14:00"` | 在指定日期的指定时间执行 |

### 使用示例

```json
// 安排任务在 3 小时后运行
{"command": "pueue_add", "arguments": {"command": "backup.sh", "delay": "3h"}}

// 安排任务在今晚 8 点运行
{"command": "pueue_add", "arguments": {"command": "report.py", "delay": "8pm"}}

// 安排任务在下周一上午 9 点运行
{"command": "pueue_add", "arguments": {"command": "weekly-sync.sh", "delay": "monday 9am"}}

// 为已暂存的任务添加延时
{"command": "pueue_enqueue", "arguments": {"ids": [5, 6], "delay": "2h"}}
```

## 顺序任务与并行任务

### 顺序任务执行（依赖关系）

使用 `pueue_add` 的 `after` 参数创建任务依赖——任务只会在指定任务完成后才开始执行：

```json
// 仅在任务 A（ID 为 1）完成后运行任务 B
{"command": "pueue_add", "arguments": {"command": "step2.sh", "after": [1]}}

// 创建流水线：build → test → deploy
{"command": "pueue_add", "arguments": {"command": "build.sh", "label": "build"}}
// 构建完成后（ID 为 2），运行测试
{"command": "pueue_add", "arguments": {"command": "test.sh", "after": [2]}}
// 测试完成后（ID 为 3），运行部署
{"command": "pueue_add", "arguments": {"command": "deploy.sh", "after": [3]}}
```

### 并行任务执行

控制组内同时运行多少个任务：

```json
// 创建一个有 4 个并行槽位的组
{"command": "pueue_group_add", "arguments": {"name": "workers", "parallel": 4}}

// 或更改现有组的并行槽位数
{"command": "pueue_parallel", "arguments": {"group": "workers", "parallel": 8}}

// 向组中添加任务 - 最多 4 个任务会并发运行
{"command": "pueue_add", "arguments": {"command": "job1.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job2.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job3.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job4.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job5.sh", "group": "workers"}}
// job5 会等待直到 job1-4 中的一个完成
```

### 综合示例：顺序 + 并行

```json
// 步骤 1: 创建一个有 2 个并行槽位的 build 组
{"command": "pueue_group_add", "arguments": {"name": "build", "parallel": 2}}

// 步骤 2: 添加并行构建任务
{"command": "pueue_add", "arguments": {"command": "build-module-a.sh", "group": "build", "label": "build-a"}}
{"command": "pueue_add", "arguments": {"command": "build-module-b.sh", "group": "build", "label": "build-b"}}
{"command": "pueue_add", "arguments": {"command": "build-module-c.sh", "group": "build", "label": "build-c"}}
// build-a 和 build-b 并行运行，build-c 等待

// 步骤 3: 在所有构建完成后部署（ID 为 10, 11, 12）
{"command": "pueue_add", "arguments": {"command": "deploy.sh", "after": [10, 11, 12], "label": "deploy"}}
```

> 当有更完整的实现可用时，可以随意替换它。

## 快速开始

1. 安装 [Vlang](https://vlang.io/)。
2. 克隆本仓库，并确保你的 `PATH` 中有可用的 `pueue` 二进制文件。
3. 构建并运行（在项目根目录下）：

   ```sh
   # 运行 core 目录下的测试
   v test core

   # 构建可执行文件
   v build -o pueue-mcp main.v

   # 或者直接运行而不编译
   v run main.v
   ```

项目中包含一个辅助脚本 `build.sh` 来简化这些步骤（见下文）。

服务器将从 stdin 读取 MCP 请求，并将响应写入 stdout。目前的实现将请求解码为字符串映射 (string map)，并将参数视为纯文本；整数数组的处理目前只是占位符 (stub)，因此仅支持基本操作。
