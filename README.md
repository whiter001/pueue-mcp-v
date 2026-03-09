# pueue-mcp-v

[中文说明](README_zh.md)

This repository is a **V language** implementation of the original [pueue-mcp](https://github.com/whiter001/pueue-mcp) project.

This project provides MCP (Model Context Protocol) tools for managing [Pueue](https://github.com/Nukesor/pueue) - a command-line tool for managing long-running shell commands with queues, groups, and dependencies.

The API signatures in
`pueue.v` and `mcp.v` are deliberately similar to the Go sources for easier
comparison.

## Supported Features

The following Pueue functionalities are exposed as MCP tools:

### Task Management

- **`pueue_add`**: Enqueue a command to be executed.
  - Parameters: `command` (required), `label`, `group`, `delay`, `working_directory`, `immediate`, `stashed`, `priority`, `after`, `raw_args`
  - **Delayed/Scheduled Execution**: Use the `delay` parameter to schedule tasks for later execution.
    - **Relative time**: `"3h"` (3 hours), `"10min"` (10 minutes), `"+60"` (60 seconds from now)
    - **Absolute time**: `"2024-12-31T23:59:59"`, `"18:00"`, `"5pm"`
    - **Day-based**: `"tomorrow"`, `"monday"`, `"wednesday 10:30pm"`, `"next friday"`
  - **Sequential Execution**: Use the `after` parameter to specify prerequisite task IDs for task dependencies
- **`pueue_enqueue`**: Enqueue stashed tasks or set/update a delay timer for them.
  - Parameters: `ids`, `all`, `group`, `delay`
  - Use this to add a delay to already stashed tasks
- **`pueue_remove`**: Remove tasks from the queue.
- **`pueue_restart`**: Restart failed or successful tasks.
- **`pueue_kill`**: Kill running tasks.
- **`pueue_wait`**: Wait for tasks to finish.

### Execution Control

- **`pueue_pause`**: Pause tasks or groups.
- **`pueue_resume`**: Resume paused tasks or groups.
- **`pueue_start`**: Start paused tasks.

### Status & Logs

- **`pueue_status`**: Get the current status of the daemon (groups and tasks).
- **`pueue_log`**: Show the log output of a specific task.

### Queue & Cleanup

- **`pueue_clean`**: Remove finished tasks from the list.
- **`pueue_group_add`**: Add a new group.
- **`pueue_group_remove`**: Remove a group.
- **`pueue_parallel`**: Set parallel tasks for a group.

## Usage with MCP Clients (e.g., Claude Desktop)

Configure your MCP client to run the `pueue-mcp` binary. The server uses standard input/output for communication.

Example configuration for Claude Desktop (`claude_desktop_config.json`):

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

Once connected, you can ask Claude to:

- "Check current pueue status"
- "Run `npm install` in the background with label 'install'"
- "Show the last 20 lines of log for task 5"
- "Clean all successful tasks"
- "Schedule a backup script to run at 2am tomorrow"
- "Run a task after another task completes"

## Scheduled & Delayed Tasks

The `pueue_add` and `pueue_enqueue` tools support flexible scheduling via the `delay` parameter:

### Delay Format Examples

| Format | Example | Description |
|--------|---------|-------------|
| Relative | `"3h"`, `"10min"`, `"+60"` | Execute after 3 hours, 10 minutes, or 60 seconds |
| Absolute | `"2024-12-31T23:59:59"`, `"18:00"`, `"5pm"` | Execute at a specific time |
| Day-based | `"tomorrow"`, `"monday"`, `"next friday"` | Execute on a specific day |
| Combined | `"wednesday 10:30pm"`, `"tomorrow 14:00"` | Execute on a specific day at a specific time |

### Usage Examples

```json
// Schedule a task to run in 3 hours
{"command": "pueue_add", "arguments": {"command": "backup.sh", "delay": "3h"}}

// Schedule a task for tonight at 8pm
{"command": "pueue_add", "arguments": {"command": "report.py", "delay": "8pm"}}

// Schedule a task for next Monday morning
{"command": "pueue_add", "arguments": {"command": "weekly-sync.sh", "delay": "monday 9am"}}

// Add a delay to already stashed tasks
{"command": "pueue_enqueue", "arguments": {"ids": [5, 6], "delay": "2h"}}
```

## Sequential & Parallel Tasks

### Sequential Task Execution (Dependencies)

Use the `after` parameter in `pueue_add` to create task dependencies - a task will only start after specified tasks complete:

```json
// Run task B only after task A (ID 1) completes
{"command": "pueue_add", "arguments": {"command": "step2.sh", "after": [1]}}

// Create a pipeline: build → test → deploy
{"command": "pueue_add", "arguments": {"command": "build.sh", "label": "build"}}
// After build completes (ID 2), run tests
{"command": "pueue_add", "arguments": {"command": "test.sh", "after": [2]}}
// After tests complete (ID 3), run deploy
{"command": "pueue_add", "arguments": {"command": "deploy.sh", "after": [3]}}
```

### Parallel Task Execution

Control how many tasks run simultaneously within a group:

```json
// Create a group with 4 parallel slots
{"command": "pueue_group_add", "arguments": {"name": "workers", "parallel": 4}}

// Or change parallel slots for an existing group
{"command": "pueue_parallel", "arguments": {"group": "workers", "parallel": 8}}

// Add tasks to the group - up to 4 will run concurrently
{"command": "pueue_add", "arguments": {"command": "job1.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job2.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job3.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job4.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job5.sh", "group": "workers"}}
// job5 will wait until one of job1-4 completes
```

### Combined Example: Sequential + Parallel

```json
// Step 1: Create a build group with 2 parallel slots
{"command": "pueue_group_add", "arguments": {"name": "build", "parallel": 2}}

// Step 2: Add parallel build tasks
{"command": "pueue_add", "arguments": {"command": "build-module-a.sh", "group": "build", "label": "build-a"}}
{"command": "pueue_add", "arguments": {"command": "build-module-b.sh", "group": "build", "label": "build-b"}}
{"command": "pueue_add", "arguments": {"command": "build-module-c.sh", "group": "build", "label": "build-c"}}
// build-a and build-b run in parallel, build-c waits

// Step 3: Deploy only after all builds complete (IDs 10, 11, 12)
{"command": "pueue_add", "arguments": {"command": "deploy.sh", "after": [10, 11, 12], "label": "deploy"}}
```

## Structure

```
.
├── main.v              # Entry point
├── core/               # Core library code
│   ├── mcp.v           # MCP server implementation
│   ├── pueue.v         # CLI client wrapper
│   └── pueue_test.v    # Unit tests
├── tests/              # Integration tests (Python + Bun real tests)
├── build.sh            # Build helper script
├── fmt.sh              # Code formatter
└── v.mod               # V module definition
```

- `main.v` – entry point that initializes a Pueue client and starts an MCP server over stdio (remains at project root).
- `core/` – directory containing the core logic:
  - `pueue.v` – CLI client that wraps calls to the `pueue` command and decodes its JSON output.
  - `mcp.v` – minimal MCP server framework with tool registration and request dispatching.
  - `pueue_test.v` – unit tests for the core functionality.
- `v.mod` – module definition for the V compiler.

> The current server implementation is a simple JSON-over-stdio dispatcher. It
> mimics the behaviour of mark3labs/mcp-go but does not depend on an external
> MCP library. Feel free to replace it with a more complete implementation as
> one becomes available.

## Getting started

1. Install [Vlang](https://vlang.io/).
2. Clone this repository and ensure you have a working `pueue` binary on your `PATH`.
3. Build and run (from project root):

   ```sh
   # Run tests
   v test core

   # Build the executable
   v -o pueue-mcp main.v

   # Or use the helper scripts
   ./build.sh        # test + build
   ./fmt.sh          # format code and markdown

   # Run without compiling
   v run main.v
   ```

### Helper Scripts

- **`build.sh`**: Runs tests and builds the binary.

  ```sh
  ./build.sh        # test + build
  ./build.sh clean # remove binary
  ```

- **`fmt.sh`**: Formats V source files and Markdown documentation.
  ```sh
  ./fmt.sh
  ```

## Testing

```sh
# Unit tests (V)
v test core

# Integration tests (Python)
python3 tests/test_mcp_integration.py

# Real end-to-end integration tests (Bun)
bun run test:real

# Or run all tests via build script
./build.sh
```

The Bun suite uses `bun:test`, builds a temporary MCP binary, talks to the real
`pueue` daemon over JSON-RPC stdio, and verifies real task execution, logs, and
status parsing.

The test suite includes **44 tests** covering:

- All 14 MCP tools
- Various parameter combinations (delay formats, group operations, etc.)
- Error handling and edge cases

The server will read MCP requests from stdin and write responses to stdout. The implementation currently decodes requests into string maps and treats parameters as plain text; the int-array handling is stubbed, so only basic operations are supported.# pueue-mcp-v

[中文说明](README_zh.md)

This repository is a **V language** implementation of the original [pueue-mcp](https://github.com/whiter001/pueue-mcp) project.

This project provides MCP (Model Context Protocol) tools for managing [Pueue](https://github.com/Nukesor/pueue) - a command-line tool for managing long-running shell commands with queues, groups, and dependencies.

The API signatures in
`pueue.v` and `mcp.v` are deliberately similar to the Go sources for easier
comparison.

## Supported Features

The following Pueue functionalities are exposed as MCP tools:

### Task Management

- **`pueue_add`**: Enqueue a command to be executed.
  - Parameters: `command` (required), `label`, `group`, `delay`, `working_directory`, `immediate`, `stashed`, `priority`, `after`, `raw_args`
  - **Delayed/Scheduled Execution**: Use the `delay` parameter to schedule tasks for later execution.
    - **Relative time**: `"3h"` (3 hours), `"10min"` (10 minutes), `"+60"` (60 seconds from now)
    - **Absolute time**: `"2024-12-31T23:59:59"`, `"18:00"`, `"5pm"`
    - **Day-based**: `"tomorrow"`, `"monday"`, `"wednesday 10:30pm"`, `"next friday"`
  - **Sequential Execution**: Use the `after` parameter to specify prerequisite task IDs for task dependencies
- **`pueue_enqueue`**: Enqueue stashed tasks or set/update a delay timer for them.
  - Parameters: `ids`, `all`, `group`, `delay`
  - Use this to add a delay to already stashed tasks
- **`pueue_remove`**: Remove tasks from the queue.
- **`pueue_restart`**: Restart failed or successful tasks.
- **`pueue_kill`**: Kill running tasks.
- **`pueue_wait`**: Wait for tasks to finish.

### Execution Control

- **`pueue_pause`**: Pause tasks or groups.
- **`pueue_resume`**: Resume paused tasks or groups.
- **`pueue_start`**: Start paused tasks.

### Status & Logs

- **`pueue_status`**: Get the current status of the daemon (groups and tasks).
- **`pueue_log`**: Show the log output of a specific task.

### Queue & Cleanup

- **`pueue_clean`**: Remove finished tasks from the list.
- **`pueue_group_add`**: Add a new group.
- **`pueue_group_remove`**: Remove a group.
- **`pueue_parallel`**: Set parallel tasks for a group.

## Usage with MCP Clients (e.g., Claude Desktop)

Configure your MCP client to run the `pueue-mcp` binary. The server uses standard input/output for communication.

Example configuration for Claude Desktop (`claude_desktop_config.json`):

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

Once connected, you can ask Claude to:

- "Check current pueue status"
- "Run `npm install` in the background with label 'install'"
- "Show the last 20 lines of log for task 5"
- "Clean all successful tasks"
- "Schedule a backup script to run at 2am tomorrow"
- "Run a task after another task completes"

## Scheduled & Delayed Tasks

The `pueue_add` and `pueue_enqueue` tools support flexible scheduling via the `delay` parameter:

### Delay Format Examples

| Format | Example | Description |
|--------|---------|-------------|
| Relative | `"3h"`, `"10min"`, `"+60"` | Execute after 3 hours, 10 minutes, or 60 seconds |
| Absolute | `"2024-12-31T23:59:59"`, `"18:00"`, `"5pm"` | Execute at a specific time |
| Day-based | `"tomorrow"`, `"monday"`, `"next friday"` | Execute on a specific day |
| Combined | `"wednesday 10:30pm"`, `"tomorrow 14:00"` | Execute on a specific day at a specific time |

### Usage Examples

```json
// Schedule a task to run in 3 hours
{"command": "pueue_add", "arguments": {"command": "backup.sh", "delay": "3h"}}

// Schedule a task for tonight at 8pm
{"command": "pueue_add", "arguments": {"command": "report.py", "delay": "8pm"}}

// Schedule a task for next Monday morning
{"command": "pueue_add", "arguments": {"command": "weekly-sync.sh", "delay": "monday 9am"}}

// Add a delay to already stashed tasks
{"command": "pueue_enqueue", "arguments": {"ids": [5, 6], "delay": "2h"}}
```

## Sequential & Parallel Tasks

### Sequential Task Execution (Dependencies)

Use the `after` parameter in `pueue_add` to create task dependencies - a task will only start after specified tasks complete:

```json
// Run task B only after task A (ID 1) completes
{"command": "pueue_add", "arguments": {"command": "step2.sh", "after": [1]}}

// Create a pipeline: build → test → deploy
{"command": "pueue_add", "arguments": {"command": "build.sh", "label": "build"}}
// After build completes (ID 2), run tests
{"command": "pueue_add", "arguments": {"command": "test.sh", "after": [2]}}
// After tests complete (ID 3), run deploy
{"command": "pueue_add", "arguments": {"command": "deploy.sh", "after": [3]}}
```

### Parallel Task Execution

Control how many tasks run simultaneously within a group:

```json
// Create a group with 4 parallel slots
{"command": "pueue_group_add", "arguments": {"name": "workers", "parallel": 4}}

// Or change parallel slots for an existing group
{"command": "pueue_parallel", "arguments": {"group": "workers", "parallel": 8}}

// Add tasks to the group - up to 4 will run concurrently
{"command": "pueue_add", "arguments": {"command": "job1.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job2.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job3.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job4.sh", "group": "workers"}}
{"command": "pueue_add", "arguments": {"command": "job5.sh", "group": "workers"}}
// job5 will wait until one of job1-4 completes
```

### Combined Example: Sequential + Parallel

```json
// Step 1: Create a build group with 2 parallel slots
{"command": "pueue_group_add", "arguments": {"name": "build", "parallel": 2}}

// Step 2: Add parallel build tasks
{"command": "pueue_add", "arguments": {"command": "build-module-a.sh", "group": "build", "label": "build-a"}}
{"command": "pueue_add", "arguments": {"command": "build-module-b.sh", "group": "build", "label": "build-b"}}
{"command": "pueue_add", "arguments": {"command": "build-module-c.sh", "group": "build", "label": "build-c"}}
// build-a and build-b run in parallel, build-c waits

// Step 3: Deploy only after all builds complete (IDs 10, 11, 12)
{"command": "pueue_add", "arguments": {"command": "deploy.sh", "after": [10, 11, 12], "label": "deploy"}}
```

## Structure

```
.
├── main.v              # Entry point
├── core/               # Core library code
│   ├── mcp.v           # MCP server implementation
│   ├── pueue.v         # CLI client wrapper
│   └── pueue_test.v    # Unit tests
├── tests/              # Integration tests (Python)
├── build.sh            # Build helper script
├── fmt.sh              # Code formatter
└── v.mod               # V module definition
```

- `main.v` – entry point that initializes a Pueue client and starts an MCP server over stdio (remains at project root).
- `core/` – directory containing the core logic:
  - `pueue.v` – CLI client that wraps calls to the `pueue` command and decodes its JSON output.
  - `mcp.v` – minimal MCP server framework with tool registration and request dispatching.
  - `pueue_test.v` – unit tests for the core functionality.
- `v.mod` – module definition for the V compiler.

> The current server implementation is a simple JSON-over-stdio dispatcher. It
> mimics the behaviour of mark3labs/mcp-go but does not depend on an external
> MCP library. Feel free to replace it with a more complete implementation as
> one becomes available.

## Getting started

1. Install [Vlang](https://vlang.io/).
2. Clone this repository and ensure you have a working `pueue` binary on your `PATH`.
3. Build and run (from project root):

   ```sh
   # Run tests
   v test core

   # Build the executable
   v -o pueue-mcp main.v

   # Or use the helper scripts
   ./build.sh        # test + build
   ./fmt.sh          # format code and markdown

   # Run without compiling
   v run main.v
   ```

### Helper Scripts

- **`build.sh`**: Runs tests and builds the binary.

  ```sh
  ./build.sh        # test + build
  ./build.sh clean # remove binary
  ```

- **`fmt.sh`**: Formats V source files and Markdown documentation.
  ```sh
  ./fmt.sh
  ```

## Testing

```sh
# Unit tests (V)
v test core

# Integration tests (Python)
python3 tests/test_mcp_integration.py

# Or run all tests via build script
./build.sh
```

The test suite includes **44 tests** covering:

- All 14 MCP tools
- Various parameter combinations (delay formats, group operations, etc.)
- Error handling and edge cases

The server will read MCP requests from stdin and write responses to stdout. The implementation currently decodes requests into string maps and treats parameters as plain text; the int-array handling is stubbed, so only basic operations are supported.
