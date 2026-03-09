# Workspace Instructions for pueue-mcp-v

This file provides guidance for AI coding agents working on this V language project.

## Project Overview

- **Project type**: V language CLI tool / MCP server
- **Description**: V language implementation of [pueue-mcp](https://github.com/whiter001/pueue-mcp) - a Model Context Protocol server for the [pueue](https://github.com/nickmcburney/pueue) task queue manager
- **Main language**: V

## Build & Test Commands

```bash
# Run tests
v test core

# Build binary
v -o pueue-mcp main.v

# Or use the helper script
./build.sh        # test + build
./build.sh clean  # remove binary

# Format code
./fmt.sh          # formats V and markdown files
```

## Project Structure

```
.
├── main.v          # Entry point
├── core/           # Core library code
│   ├── mcp.v       # MCP server implementation
│   ├── pueue.v     # Pueue CLI client wrapper
│   └── pueue_test.v
├── build.sh        # Build helper script
├── fmt.sh          # Code formatter (v fmt + oxfmt for markdown)
├── README.md       # English documentation
├── README_zh.md    # Chinese documentation
└── .gitignore
```

## Key Conventions

1. **Module organization**: Core code lives in `core/` directory with `module core`
2. **Testing**: Tests are co-located in `core/pueue_test.v`
3. **Error handling**: Use V's `!string` (noreturn) error handling pattern
4. **Parameters**: MCP parameter handling uses `map[string]string` for simplicity
5. **Documentation**: Maintain both English (README.md) and Chinese (README_zh.md) docs
6. **Formatting**: Run `./fmt.sh` before commits to keep code and docs consistent

## Architecture Notes

- The MCP server reads JSON requests from stdin and writes responses to stdout
- The `pueue.v` client wraps the `pueue` CLI tool and parses JSON output
- Current implementation is a simplified JSON-over-stdio dispatcher (not a full MCP library)

## Common Issues

- When modifying MCP parameter handling, remember V's strict typing - avoid `any` type
- Use `map[string]string` instead of complex nested maps for parameters
- Array handling in JSON is stubbed; expand `get_int_array` if needed
