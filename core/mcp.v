module core

import os
import json

pub type RpcId = string | int

pub struct JsonRpcRequest {
    jsonrpc string
    method  string
}

// -- Helper structs for decoding specific request types with different ID types --
struct InitReqStr { jsonrpc string method string id string params InitializeParams }
struct InitReqInt { jsonrpc string method string id int    params InitializeParams }

struct CallReqStr { jsonrpc string method string id string params CallToolParams }
struct CallReqInt { jsonrpc string method string id int    params CallToolParams }

struct ListReqStr { jsonrpc string method string id string }
struct ListReqInt { jsonrpc string method string id int }

// -- JSON-RPC Response --
pub struct JsonRpcResponse[T] {
    jsonrpc string = '2.0'
    id      RpcId 
    result  T      @[json: 'result']
}

pub struct JsonRpcErrorResponse {
    jsonrpc string = '2.0'
    id      ?RpcId 
    err     JsonRpcError @[json: 'error']
}

pub struct JsonRpcError {
    code    int
    message string
}

// -- MCP Payloads --

struct InitializeParams {
    protocol_version string @[json: 'protocolVersion']
    client_info      ClientInfo @[json: 'clientInfo']
    capabilities     map[string]map[string]string
}

struct ClientInfo {
    name    string
    version string
}

struct InitializeResult {
    protocol_version string @[json: 'protocolVersion']
    capabilities     ServerCapabilities
    server_info      ServerInfo @[json: 'serverInfo']
}

struct ServerCapabilities {
    logging map[string]string = map[string]string{}
    tools   map[string]string = map[string]string{}
}

struct ServerInfo {
    name    string
    version string
}

struct CallToolParams {
    name      string
    arguments ToolArguments
}

struct ToolArguments {
    // Add/Common
    command         string
    label           string
    group           string
    delay           string
    working_directory string @[json: 'working_directory']
    immediate       bool
    stashed         bool
    priority        ?int
    after           []int
    escape          bool
    raw_args        []string @[json: 'raw_args']
    
    // Log/Kill/Common
    ids             []int
    id              int
    id1             int // switch
    id2             int // switch
    lines           int
    parallel        int
    name            string // group name
    successful_only bool @[json: 'successful_only']
    all             bool
    full            bool
    signal          string
    input           string // send
    path            string // edit
    
    // Restart/Start/Pause specific
    all_failed         bool @[json: 'all_failed']
    failed_in_group    string @[json: 'failed_in_group']
    start_immediately  bool @[json: 'start_immediately']
    in_place           bool @[json: 'in_place']
    children           bool // kill/pause/start children
    wait               bool // pause wait
    force              bool // reset force
}

struct CallToolResult {
    content  []Content
    is_error bool @[json: 'isError']
}

struct Content {
    typ  string = 'text' @[json: 'type']
    text string
}

struct ListToolsResult {
    tools []Tool
}

struct Tool {
    name         string
    description  string
    input_schema ToolInputSchema @[json: 'inputSchema']
}

struct ToolInputSchema {
    typ        string = 'object' @[json: 'type']
    properties map[string]ToolProperty
    required   []string
}

struct ToolProperty {
    typ         string @[json: 'type']
    description string
    items       ?ToolPropertyItems 
}

struct ToolPropertyItems {
    typ string @[json: 'type']
}

// -- Server Implementation --

pub struct PueueMCPServer {
    client core.PueueClient
}

pub fn new_pueue_mcp_server(client core.PueueClient) PueueMCPServer {
    return PueueMCPServer{client: client}
}

pub fn (mut s PueueMCPServer) serve() ? {
    for {
        line := os.get_line()
        if line.len == 0 { break }
        trimmed := line.trim_space()
        if trimmed == '' { continue }

        // Peek at method to decide how to decode
        base := json.decode(JsonRpcRequest, trimmed) or {
            eprintln('JSON decode error: $err')
            continue
        }

        resp := s.dispatch(base.method, trimmed)
        if resp != '' {
            println(resp)
        }
    }
}

fn (mut s PueueMCPServer) dispatch(method string, json_str string) string {
    match method {
        'initialize' {
            if req := json.decode(InitReqStr, json_str) { return s.process_initialize(req.params, RpcId(req.id)) }
            if req := json.decode(InitReqInt, json_str) { return s.process_initialize(req.params, RpcId(req.id)) }
        }
        'tools/list' {
             if req := json.decode(ListReqStr, json_str) { return s.process_list_tools(RpcId(req.id)) }
             if req := json.decode(ListReqInt, json_str) { return s.process_list_tools(RpcId(req.id)) }
        }
        'tools/call' {
             if req := json.decode(CallReqStr, json_str) { return s.process_call_tool(req.params, RpcId(req.id)) }
             if req := json.decode(CallReqInt, json_str) { return s.process_call_tool(req.params, RpcId(req.id)) }
        }
        'notifications/initialized' { return '' }
        else {
             // Try to extract ID for error response
             mut eid := ?RpcId(none)
             if req_s := json.decode(struct{id string}, json_str) { eid = RpcId(req_s.id) }
             else if req_i := json.decode(struct{id int}, json_str) { eid = RpcId(req_i.id) }
             return s.error_response(eid, -32601, 'Method not found: $method')
        }
    }
    return s.error_response(none, -32600, 'Invalid Request')
}

fn (s PueueMCPServer) process_initialize(params InitializeParams, id RpcId) string {
    res := InitializeResult{
        protocol_version: '2024-11-05'
        capabilities: ServerCapabilities{ tools: {'listChanged': 'true'} }
        server_info: ServerInfo{ name: 'pueue-mcp-v', version: '0.1.0' }
    }
    return json.encode(JsonRpcResponse[InitializeResult]{ id: id, result: res })
}

fn (s PueueMCPServer) process_list_tools(id RpcId) string {
    tools := [
        Tool{
            name: 'pueue_status'
            description: 'Get the current status of the Pueue daemon, including groups and tasks.'
            input_schema: ToolInputSchema{
                properties: map[string]ToolProperty{}
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_add'
            description: 'Enqueue a command to be executed. Support advanced DELAY formats like "today 18:30", "+10 minutes", "monday", "3h".'
            input_schema: ToolInputSchema{
                properties: {
                    'command': ToolProperty{typ: 'string', description: 'The command to execute'}
                    'label':   ToolProperty{typ: 'string', description: 'Label for the task'}
                    'group':   ToolProperty{typ: 'string', description: 'Group to run the task in'}
                    'delay':   ToolProperty{typ: 'string', description: 'Delay execution. Format examples: "2024-12-31T23:59:59", "18:00", "5pm", "3h", "10min", "tomorrow", "wednesday 10:30pm"'}
                    'working_directory': ToolProperty{typ: 'string', description: 'Specify current working directory'}
                    'immediate': ToolProperty{typ: 'boolean', description: 'Immediately start the task'}
                    'stashed':   ToolProperty{typ: 'boolean', description: 'Create the task in Stashed state (queued but not running)'}
                    'priority':  ToolProperty{typ: 'integer', description: 'Task priority (higher number = faster processing)'}
                    'after':     ToolProperty{typ: 'array', description: 'Start task after these task IDs finish', items: ToolPropertyItems{typ: 'integer'}}
                    'raw_args':  ToolProperty{typ: 'array', description: 'Additional raw flags to pass to pueue add', items: ToolPropertyItems{typ: 'string'}}
                }
                required: ['command']
            }
        },
        Tool{
            name: 'pueue_log'
            description: 'Show the log output of tasks.'
            input_schema: ToolInputSchema{
                properties: {
                    'id':    ToolProperty{typ: 'integer', description: 'Specific Task ID (optional if ids/group/all provided)'}
                    'ids':   ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                    'group': ToolProperty{typ: 'string', description: 'View logs for tasks in this group'}
                    'all':   ToolProperty{typ: 'boolean', description: 'View logs for all tasks'}
                    'lines': ToolProperty{typ: 'integer', description: 'Number of lines to show (tail)'}
                    'full':  ToolProperty{typ: 'boolean', description: 'Show full log output'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_wait'
            description: 'Wait for tasks to finish.'
            input_schema: ToolInputSchema{
                properties: {
                    'ids':   ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                    'group': ToolProperty{typ: 'string', description: 'Wait for all tasks in a group'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_clean'
            description: 'Remove finished tasks from the list.'
            input_schema: ToolInputSchema{
                properties: {
                    'successful_only': ToolProperty{typ: 'boolean', description: 'Only clean successful tasks'}
                    'group':           ToolProperty{typ: 'string', description: 'Clean only tasks in this group'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_kill'
            description: 'Kill running tasks.'
            input_schema: ToolInputSchema{
                properties: {
                    'ids':    ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                    'group':  ToolProperty{typ: 'string', description: 'Kill all tasks in this group'}
                    'all':    ToolProperty{typ: 'boolean', description: 'Kill all running tasks across ALL groups'}
                    'signal': ToolProperty{typ: 'string', description: 'Send specific UNIX signal (e.g. "sigint", "9")'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_pause'
            description: 'Pause tasks or groups.'
            input_schema: ToolInputSchema{
                properties: {
                    'ids':      ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                    'group':    ToolProperty{typ: 'string', description: 'Pause all tasks in this group'}
                    'all':      ToolProperty{typ: 'boolean', description: 'Pause all groups!'}
                    'wait':     ToolProperty{typ: 'boolean', description: 'Wait for running tasks to finish before pausing'}
                    'children': ToolProperty{typ: 'boolean', description: 'Pause children processes too'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_resume'
            description: 'Resume paused tasks or groups.'
            input_schema: ToolInputSchema{
                properties: {
                    'ids':   ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                    'group': ToolProperty{typ: 'string', description: 'Resume all tasks in this group'}
                    'all':   ToolProperty{typ: 'boolean', description: 'Resume all groups!'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_restart'
            description: 'Restart tasks.'
            input_schema: ToolInputSchema{
                properties: {
                    'ids':               ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                    'all_failed':        ToolProperty{typ: 'boolean', description: 'Restart all failed tasks'}
                    'failed_in_group':   ToolProperty{typ: 'string', description: 'Restart failed tasks in group'}
                    'start_immediately': ToolProperty{typ: 'boolean', description: 'Start immediately'}
                    'in_place':          ToolProperty{typ: 'boolean', description: 'Restart in place (same ID, replacing old task)'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_start'
            description: 'Start paused tasks.'
            input_schema: ToolInputSchema{
                properties: {
                    'ids':      ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                    'group':    ToolProperty{typ: 'string', description: 'Start all tasks in this group'}
                    'all':      ToolProperty{typ: 'boolean', description: 'Start all groups'}
                    'children': ToolProperty{typ: 'boolean', description: 'Start children processes too'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_switch'
            description: 'Switch the queue position of two commands.'
            input_schema: ToolInputSchema{
                properties: {
                    'id1': ToolProperty{typ: 'integer', description: 'First Task ID'}
                    'id2': ToolProperty{typ: 'integer', description: 'Second Task ID'}
                }
                required: ['id1', 'id2']
            }
        },
        Tool{
            name: 'pueue_stash'
            description: 'Stash specific tasks (pause them).'
            input_schema: ToolInputSchema{
                properties: {
                    'ids': ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                }
                required: ['ids']
            }
        },
        Tool{
            name: 'pueue_enqueue'
            description: 'Enqueue stashed tasks or set/update a delay (timer) for them.'
            input_schema: ToolInputSchema{
                properties: {
                    'ids':   ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                    'all':   ToolProperty{typ: 'boolean', description: 'Enqueue all stashed tasks'}
                    'group': ToolProperty{typ: 'string', description: 'Enqueue all stashed tasks in this group'}
                    'delay': ToolProperty{typ: 'string', description: 'Delay execution. Format examples: "3h", "10min", "20:00", "tomorrow", "next monday"'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_reset'
            description: 'Kill all tasks, clean up afterwards and reset EVERYTHING!'
            input_schema: ToolInputSchema{
                properties: {
                    'children': ToolProperty{typ: 'boolean', description: 'Kill children too'}
                    'force':    ToolProperty{typ: 'boolean', description: 'Force reset (needed for running tasks)'}
                }
                required: []string{}
            }
        },
        Tool{
            name: 'pueue_send'
            description: 'Send something to a task input.'
            input_schema: ToolInputSchema{
                properties: {
                    'id':    ToolProperty{typ: 'integer', description: 'Task ID'}
                    'input': ToolProperty{typ: 'string', description: 'Input string to send'}
                }
                required: ['id', 'input']
            }
        },
        Tool{
            name: 'pueue_edit'
            description: 'Edit a task.'
            input_schema: ToolInputSchema{
                properties: {
                    'id':       ToolProperty{typ: 'integer', description: 'Task ID'}
                    'command':  ToolProperty{typ: 'string', description: 'New command'}
                    'path':     ToolProperty{typ: 'string', description: 'New path'}
                    'label':    ToolProperty{typ: 'string', description: 'New label'}
                    'priority': ToolProperty{typ: 'integer', description: 'New priority'}
                }
                required: ['id']
            }
        },
        Tool{
            name: 'pueue_remove'
            description: 'Remove tasks from the queue.'
            input_schema: ToolInputSchema{
                properties: {
                    'ids': ToolProperty{typ: 'array', description: 'List of Task IDs', items: ToolPropertyItems{typ: 'integer'}}
                }
                required: ['ids']
            }
        },
         Tool{
            name: 'pueue_group_add'
            description: 'Add a new group.'
            input_schema: ToolInputSchema{
                properties: {
                    'name':     ToolProperty{typ: 'string', description: 'Name of the group'}
                    'parallel': ToolProperty{typ: 'integer', description: 'Number of parallel tasks'}
                }
                required: ['name']
            }
        },
        Tool{
            name: 'pueue_group_remove'
            description: 'Remove a group.'
            input_schema: ToolInputSchema{
                properties: {
                    'name': ToolProperty{typ: 'string', description: 'Name of the group'}
                }
                required: ['name']
            }
        },
         Tool{
            name: 'pueue_parallel'
            description: 'Set parallel tasks for a group.'
            input_schema: ToolInputSchema{
                properties: {
                    'group':    ToolProperty{typ: 'string', description: 'Name of the group'}
                    'parallel': ToolProperty{typ: 'integer', description: 'Number of parallel tasks'}
                }
                required: ['parallel']
            }
        },
    ]
    
    return json.encode(JsonRpcResponse[ListToolsResult]{ id: id, result: ListToolsResult{tools: tools} })
}

fn (s PueueMCPServer) process_call_tool(params CallToolParams, id RpcId) string {
    args := params.arguments
    mut output := ''
    mut err_msg := ''
    
    match params.name {
        'pueue_status' {
            if resp := s.client.status() { output = s.format_status(resp) } 
            else { err_msg = err.msg() }
        }
        'pueue_add' {
            if args.command == '' { err_msg = 'command is required' }
            else {
                opts := core.AddOptions{
                    label: args.label
                    group: args.group
                    delay: args.delay
                    working_directory: args.working_directory
                    immediate: args.immediate
                    stashed: args.stashed
                    priority: args.priority
                    after: args.after
                    escape: args.escape
                    raw_args: args.raw_args
                }
                if res := s.client.add(args.command, opts) { output = res }
                else { err_msg = err.msg() }
            }
        }
        'pueue_log' {
            mut ids := args.ids.clone()
            if args.id != 0 { ids << args.id }
            opts := core.LogOptions{
                ids: ids
                group: args.group
                all: args.all
                lines: if args.lines > 0 { args.lines } else { none }
                full: args.full
            }
            if res := s.client.log(opts) { output = res }
            else { err_msg = err.msg() }
        }
        'pueue_clean' {
            if res := s.client.clean(args.successful_only, args.group) { output = res }
            else { err_msg = err.msg() }
        }
        'pueue_wait' {
            if res := s.client.wait(args.ids, args.group) { output = res }
            else { err_msg = err.msg() }
        }
        'pueue_group_add' {
            if args.name == '' { err_msg = 'name is required' }
            else {
                 if res := s.client.group_add(args.name, args.parallel) { output = res }
                 else { err_msg = err.msg() }
            }
        }
        'pueue_group_remove' {
            if args.name == '' { err_msg = 'name is required' }
            else {
                 if res := s.client.group_remove(args.name) { output = res }
                 else { err_msg = err.msg() }
            }
        }
        'pueue_parallel' {
             if res := s.client.parallel(args.group, args.parallel) { output = res }
             else { err_msg = err.msg() }
        }
        'pueue_pause' {
             if res := s.client.pause(args.ids, args.group, args.all, args.wait, args.children) { output = res } else { err_msg = err.msg() }
        }
        'pueue_resume' {
             if res := s.client.start(args.ids, args.group, args.all, args.children) { output = res } else { err_msg = err.msg() }
        }
        'pueue_kill' {
             if res := s.client.kill(args.ids, args.group, args.all, args.signal) { output = res } else { err_msg = err.msg() }
        }
        'pueue_start' {
             if res := s.client.start(args.ids, args.group, args.all, args.children) { output = res } else { err_msg = err.msg() }
        }
        'pueue_restart' {
             if res := s.client.restart(args.ids, args.all_failed, args.failed_in_group, args.start_immediately, args.in_place) { output = res } else { err_msg = err.msg() }
        }
        'pueue_remove' {
             if res := s.client.remove(args.ids) { output = res } else { err_msg = err.msg() }
        }
        'pueue_switch' {
             if res := s.client.switch(args.id1, args.id2) { output = res } else { err_msg = err.msg() }
        }
        'pueue_stash' {
             if res := s.client.stash(args.ids) { output = res } else { err_msg = err.msg() }
        }
        'pueue_enqueue' {
             if res := s.client.enqueue(args.ids, args.delay) { output = res } else { err_msg = err.msg() }
        }
        'pueue_reset' {
             if res := s.client.reset(args.children, args.force) { output = res } else { err_msg = err.msg() }
        }
        'pueue_send' {
             if res := s.client.send(args.id, args.input) { output = res } else { err_msg = err.msg() }
        }
        'pueue_edit' {
             if res := s.client.edit(args.id, args.command, args.path, args.label, args.priority) { output = res } else { err_msg = err.msg() }
        }
        else {
            return s.error_response(id, -32601, 'Tool not found: $params.name')
        }
    }

    if err_msg != '' {
        return json.encode(JsonRpcResponse[CallToolResult]{
            id: id, 
            result: CallToolResult{
                is_error: true, 
                content: [Content{text: err_msg}]
            }
        })
    }

    return json.encode(JsonRpcResponse[CallToolResult]{
        id: id, 
        result: CallToolResult{
            is_error: false, 
            content: [Content{text: output}]
        }
    })
}

fn (s PueueMCPServer) format_status(resp core.StatusResponse) string {
    mut msg := ''
    if resp.groups.len > 0 {
        msg += 'Pueue Groups:\n'
        for name, group in resp.groups {
            msg += '- $name: $group.status (Parallel: $group.parallel_tasks)\n'
        }
        msg += '\n'
    }
    msg += 'Pueue Tasks:\n'
    if resp.tasks.len == 0 {
        msg += 'No tasks in queue.'
    } else {
        for id, task in resp.tasks {
            exit_info := if task.exit_code != none { ' (Exit Code: ${task.exit_code})' } else { '' }
            msg += '[$id] $task.status - $task.command (Group: $task.group)$exit_info\n'
        }
    }
    return msg
}

fn (s PueueMCPServer) error_response(id ?RpcId, code int, msg string) string {
    return json.encode(JsonRpcErrorResponse{
        id: id
        err: JsonRpcError{code: code, message: msg}
    })
}
