module main

import core

fn main() {
    // Initialize Pueue client
    client := core.new_cli_client()

    // Initialize MCP server (requires mutable receiver)
    mut server := core.new_pueue_mcp_server(client)

    // Serve using stdio transport
    server.serve() or {
        eprintln('MCP server error: $err')
        exit(1)
    }
}
