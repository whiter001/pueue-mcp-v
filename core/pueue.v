module core

import os
import time
import json

pub enum TaskStatus {
    queued
    stashed
    running
    paused
    success
    failed
    killed
}

pub struct Task {
    id           int
    command      string
    path         string
    status       TaskStatus
    label        string
    start        ?time.Time
    end          ?time.Time
    enqueue_time ?time.Time
    group        string
    exit_code    ?int
}

pub struct GroupInfo {
    status        string
    parallel_tasks int
}

pub struct StatusResponse {
    tasks  map[string]Task
    groups map[string]GroupInfo
}

pub struct AddOptions {
pub:
    label             string
    group             string
    delay             string
    working_directory string
    immediate         bool
    stashed           bool
    priority          ?int
    after             []int
    escape            bool
    raw_args          []string
}

pub struct LogOptions {
pub:
    ids      []int
    group    string
    all      bool
    lines    ?int
    full     bool
}

pub interface PueueClient {
    add(command string, opts AddOptions) !string
    add_with_args(command string, args []string, opts AddOptions) !string
    status() !StatusResponse
    log(opts LogOptions) !string
    remove(ids []int) !string
    switch(id1 int, id2 int) !string
    stash(ids []int) !string
    enqueue(ids []int, delay string) !string
    start(ids []int, group string, all bool, children bool) !string
    pause(ids []int, group string, all bool, wait bool, children bool) !string
    kill(ids []int, group string, all bool, signal string) !string
    restart(ids []int, all_failed bool, failed_in_group string, start_immediately bool, in_place bool) !string
    clean(successful_only bool, group string) !string
    reset(children bool, force bool) !string
    send(id int, input string) !string
    edit(id int, command string, path string, label string, priority ?int) !string
    wait(ids []int, group string) !string
    group_add(name string, parallel int) !string
    group_remove(name string) !string
    parallel(group string, parallel int) !string
}

pub struct CLIClient {
    pub mut:
    pueue_path string
}

pub fn new_cli_client() CLIClient {
    return CLIClient{pueue_path: 'pueue'}
}

fn quote_arg(arg string) string {
    if arg == '' { return '""' }
    if !arg.contains(' ') && !arg.contains('"') && !arg.contains("'") && !arg.contains('\t') && !arg.contains('\n') && !arg.contains(';') {
        return arg
    }
    // Escape double quotes and wrap in double quotes (works for most shells)
    escaped := arg.replace('"', '\\"')
    return '"$escaped"'
}

pub fn (c CLIClient) run(args []string) !string {
    // Quote arguments to ensure safety with spaces/special chars
    mut cmd := [quote_arg(c.pueue_path)]
    for arg in args {
        cmd << quote_arg(arg)
    }
    
    full_cmd := cmd.join(' ')
    // println('Executing: $full_cmd') // Debug
    res := os.execute(full_cmd)
    if res.exit_code != 0 {
        return error('command failed: $res.output')
    }
    return res.output
}

fn build_add_args(command string, opts AddOptions) []string {
    mut args := ['add']
    if opts.label.len > 0 {
        args << '--label'
        args << opts.label
    }
    if opts.group.len > 0 {
        args << '--group'
        args << opts.group
    }
    if opts.delay.len > 0 {
        args << '--delay'
        args << opts.delay
    }
    if opts.working_directory.len > 0 {
        args << '--working-directory'
        args << opts.working_directory
    }
    if opts.immediate {
        args << '--immediate'
    }
    if opts.stashed {
        args << '--stashed'
    }
    if opts.escape {
        args << '--escape'
    }
    if priority := opts.priority {
        args << '--priority'
        args << priority.str()
    }
    if opts.after.len > 0 {
        args << '--after'
        for id in opts.after {
            args << id.str()
        }
    }
    if opts.raw_args.len > 0 {
        args << opts.raw_args
    }
    args << '--'
    args << command
    return args
}

pub fn (c CLIClient) add(command string, opts AddOptions) !string {
    args := build_add_args(command, opts)
    return c.run(args)
}

pub fn (c CLIClient) add_with_args(command string, cmd_args []string, opts AddOptions) !string {
    mut args := build_add_args(command, opts)
    args << cmd_args
    return c.run(args)
}

pub fn (c CLIClient) status() !StatusResponse {
    output := c.run(['status', '--json'])!
    resp := json.decode(StatusResponse, output)!
    return resp
}

pub fn (c CLIClient) log(opts LogOptions) !string {
    mut args := ['log']
    if opts.group.len > 0 {
        args << '--group'
        args << opts.group
    }
    if opts.all {
        args << '--all'
    }
    if opts.full {
        args << '--full'
    }
    if lines := opts.lines {
        args << '--lines'
        args << lines.str()
    }
    for id in opts.ids {
        args << id.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) remove(ids []int) !string {
    mut args := ['remove']
    for id in ids {
        args << id.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) switch(id1 int, id2 int) !string {
    return c.run(['switch', id1.str(), id2.str()])
}

pub fn (c CLIClient) stash(ids []int) !string {
    mut args := ['stash']
    for id in ids {
        args << id.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) enqueue(ids []int, delay string) !string {
    mut args := ['enqueue']
    if delay.len > 0 {
        args << '--delay'
        args << delay
    }
    for id in ids {
        args << id.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) start(ids []int, group string, all bool, children bool) !string {
    mut args := ['start']
    if group.len > 0 {
        args << '--group'
        args << group
    }
    if all {
        args << '--all'
    }
    if children {
        args << '--children'
    }
    for id in ids {
        args << id.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) pause(ids []int, group string, all bool, wait bool, children bool) !string {
    mut args := ['pause']
    if group.len > 0 {
        args << '--group'
        args << group
    }
    if all {
        args << '--all'
    }
    if wait {
        args << '--wait'
    }
    if children {
        args << '--children'
    }
    for id in ids {
        args << id.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) restart(ids []int, all_failed bool, failed_in_group string, start_immediately bool, in_place bool) !string {
    mut args := ['restart']
    if all_failed {
        args << '--all-failed'
    }
    if failed_in_group.len > 0 {
        args << '--failed-in-group'
        args << failed_in_group
    }
    if start_immediately {
        args << '--start-immediately'
    }
    if in_place {
        args << '--in-place'
    }
    for id in ids {
        args << id.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) kill(ids []int, group string, all bool, signal string) !string {
    mut args := ['kill']
    if all {
        args << '--all'
    }
    if group.len > 0 {
        args << '--group'
        args << group
    }
    if signal.len > 0 {
        args << '--signal'
        args << signal
    }
    for id in ids {
        args << id.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) clean(successful_only bool, group string) !string {
    mut args := ['clean']
    if successful_only {
        args << '--successful-only'
    }
    if group.len > 0 {
        args << '--group'
        args << group
    }
    return c.run(args)
}

pub fn (c CLIClient) reset(children bool, force bool) !string {
    mut args := ['reset']
    if children {
        args << '--children'
    }
    if force {
        args << '--force'
    }
    return c.run(args)
}

pub fn (c CLIClient) send(id int, input string) !string {
    // send input to task
    mut args := ['send', id.str(), input]
    return c.run(args)
}

pub fn (c CLIClient) edit(id int, command string, path string, label string, priority ?int) !string {
    mut args := ['edit', id.str()]
    if command.len > 0 {
        args << '--command'
        args << command
    }
    if path.len > 0 {
        args << '--path'
        args << path
    }
    if label.len > 0 {
        args << '--label'
        args << label
    }
    if prio := priority {
        args << '--priority'
        args << prio.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) wait(ids []int, group string) !string {
    mut args := ['wait']
    if group.len > 0 {
        args << '--group'
        args << group
    }
    for id in ids {
        args << id.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) group_add(name string, parallel int) !string {
    mut args := ['group', 'add', name]
    if parallel > 0 {
        args << '--parallel'
        args << parallel.str()
    }
    return c.run(args)
}

pub fn (c CLIClient) group_remove(name string) !string {
    return c.run(['group', 'remove', name])
}

pub fn (c CLIClient) parallel(group string, parallel int) !string {
    mut args := ['parallel']
    if group.len > 0 {
        args << group
    }
    args << parallel.str()
    return c.run(args)
}
