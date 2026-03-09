# AGENTS.md - Development Guide for pueue-mcp-v

## Project Overview

- **Project type**: V language CLI tool / MCP server
- **Description**: V language implementation of [pueue-mcp](https://github.com/whiter001/pueue-mcp) - a Model Context Protocol server for the [pueue](https://github.com/nickmcburney/pueue) task queue manager
- **Main language**: V (vlang)

## Build, Lint & Test Commands

### Running Tests

```bash
# Run all unit tests in core module
v test core

# Run a single test by name (V doesn't have a dedicated -run flag, use test filtering)
v test core -run TestName

# Run tests via helper script
./build.sh          # Unix: runs tests + builds binary
./build.sh clean    # Unix: remove binary
.\build.ps1         # Windows: runs tests + builds binary
.\build.ps1 clean   # Windows: remove binary

# Run integration tests (Python)
python3 tests/test_mcp_integration.py
```

### Building

```bash
# Build binary directly
v -o pueue-mcp main.v           # Unix
v -o pueue-mcp.exe main.v       # Windows

# Run without compiling
v run main.v
```

### Formatting

```bash
# Format V source files
v fmt .

# Or use the helper script (formats V + Markdown)
./fmt.sh          # Unix
```

## Code Style Guidelines

### General Principles

- Follow V language conventions as seen in existing code
- Keep code simple and readable
- Use explicit typing - avoid `any` type
- Prefer `map[string]string` over complex nested maps for parameters

### Module Organization

```v
module core

// Imports at top
import os
import json
import time
```

- Core library code lives in `core/` directory with `module core`
- Entry point is `main.v` with `module main`
- Tests are co-located: `core/pueue_test.v`

### Naming Conventions

- **Types** (structs, enums, interfaces): `PascalCase`
  ```v
  pub struct Task { ... }
  pub enum TaskStatus { ... }
  pub interface PueueClient { ... }
  ```

- **Functions/Variables**: `snake_case`
  ```v
  fn build_add_args(...) { ... }
  mut server := core.new_pueue_mcp_server(client)
  ```

- **Constants**: `SCREAMING_SNAKE_CASE` (if any)

### Structs & Visibility

```v
// Public struct with public fields
pub struct Task {
    id      int
    command string
}

// Public struct with options pattern
pub struct AddOptions {
pub:
    label string
    group string
}

// Mutable private fields
pub struct PueueMCPServer {
    client core.PueueClient
mut:
    log_level string = 'info'
}
```

### Error Handling

Use V's `!string` (noreturn) error handling pattern:

```v
pub fn (c CLIClient) add(command string, opts AddOptions) !string {
    args := build_add_args(command, opts)
    return c.run(args)
}

// With error message
pub fn (c CLIClient) start_daemon() !string {
    res := os.execute('pueued -d')
    if res.exit_code != 0 {
        return error('Failed to start daemon: $res.output')
    }
    return 'Daemon started successfully'
}
```

### Optional Types

Use `?` for optional values:

```v
pub struct Task {
    start     ?time.Time
    end       ?time.Time
    exit_code ?int
}

// Access with `if` statement
if code := task.exit_code {
    // use code
}
```

### JSON Handling

Use struct tags for JSON field mapping:

```v
pub struct InitializeParams {
    protocol_version string @[json: 'protocolVersion']
    client_info      ClientInfo @[json: 'clientInfo']
}

struct ToolArguments {
    command string
    working_directory string @[json: 'working_directory']
    ids     []int
}
```

### String Interpolation

Use `$var` or `${expr}` for string interpolation:

```v
return 'Failed to start daemon: $res.output'
msg += '[$id] $task.status - $task.command\n'
```

### Control Flow

Prefer `match` over long `if-else` chains:

```v
match method {
    'initialize' { ... }
    'tools/list' { ... }
    'tools/call' { ... }
    else { ... }
}
```

### Array/Map Operations

```v
// Building argument arrays
mut args := ['add']
args << '--label'
args << opts.label

// Map initialization
capabilities: ServerCapabilities{
    logging: {'setLevel': 'true'}
    tools: {'listChanged': 'true'}
}

// Map access
if val := mymap[key] { ... }
```

### Interface Pattern

Define interfaces for abstraction:

```v
pub interface PueueClient {
    start_daemon() !string
    status() !StatusResponse
    add(command string, opts AddOptions) !string
    // ... other methods
}
```

## Project Structure

```
.
├── main.v              # Entry point (module main)
├── core/               # Core library (module core)
│   ├── mcp.v           # MCP server implementation
│   ├── pueue.v         # Pueue CLI client wrapper
│   └── pueue_test.v    # Unit tests
├── tests/              # Integration tests (Python)
├── build.sh            # Unix build helper
├── build.ps1           # Windows build helper
├── fmt.sh              # Code formatter
├── v.mod               # V module definition
└── README.md           # English documentation
```

## Architecture Notes

- MCP server reads JSON requests from stdin and writes responses to stdout
- The `pueue.v` client wraps the `pueue` CLI tool and parses JSON output
- Current implementation is a simplified JSON-over-stdio dispatcher
- Keep API signatures similar to other language implementations for easier comparison

## Documentation

- Maintain both English (README.md) and Chinese (README_zh.md) docs
- Document new MCP tools in `process_list_tools()` in `core/mcp.v`
- Run `./fmt.sh` before commits to format code and docs
