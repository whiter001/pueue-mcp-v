# pueue-mcp-v

这个仓库是原版 [pueue-mcp](https://github.com/whiter001/pueue-mcp) 项目的 **V 语言** 实现。

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

- “查看当前的 pueue 状态”
- “帮我后台执行 `v build` 命令，并打上 `build` 标签”
- “查看任务 ID 为 5 的最后 20 行日志”
- “清理所有成功的 pueue 任务”

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
