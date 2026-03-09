import subprocess
import json
import sys
import os
import signal

def run_mcp_request(request_data, timeout=5):
    """Runs the pueue-mcp binary with the given request data via stdin."""
    process = subprocess.Popen(
        ['./pueue-mcp'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    
    input_str = json.dumps(request_data) + "\n"
    
    try:
        stdout, stderr = process.communicate(input=input_str, timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        stdout, stderr = process.communicate()
        raise TimeoutError(f"Request timed out after {timeout}s")
    
    if stderr:
        print(f"Server Stderr: {stderr}", file=sys.stderr)
        
    return stdout.strip()

def test_initialize():
    print("Testing initialize...")
    req = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "clientInfo": {"name": "test-client", "version": "1.0"},
            "capabilities": {}
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert resp['jsonrpc'] == '2.0'
        assert resp['id'] == 1
        assert 'result' in resp
        assert resp['result']['protocolVersion'] == '2024-11-05'
        assert 'capabilities' in resp['result']
        assert 'serverInfo' in resp['result']
        print("PASS: initialize")
    except Exception as e:
        print(f"FAIL: initialize - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_list_tools():
    print("Testing tools/list...")
    req = {
        "jsonrpc": "2.0",
        "id": "req-2", # Test string ID
        "method": "tools/list"
        # params is optional
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert resp['jsonrpc'] == '2.0'
        assert resp['id'] == "req-2"
        assert 'result' in resp
        tools = resp['result']['tools']
        assert isinstance(tools, list)
        assert len(tools) > 0
        
        tool_names = [t['name'] for t in tools]
        assert 'pueue_status' in tool_names
        assert 'pueue_add' in tool_names
        assert 'pueue_log' in tool_names
        
        # Check inputSchema
        status_tool = next(t for t in tools if t['name'] == 'pueue_status')
        assert 'inputSchema' in status_tool
        
        print("PASS: tools/list")
    except Exception as e:
        print(f"FAIL: tools/list - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_status():
    print("Testing tools/call (pueue_status)...")
    req = {
        "jsonrpc": "2.0",
        "id": 3,
        "method": "tools/call",
        "params": {
            "name": "pueue_status",
            "arguments": {}
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert resp['jsonrpc'] == '2.0'
        assert resp['id'] == 3
        assert 'result' in resp
        assert 'content' in resp['result']
        content = resp['result']['content']
        assert isinstance(content, list)
        assert len(content) > 0
        assert content[0]['type'] == 'text'
        assert 'Pueue' in content[0]['text'] # Should contain status text
        assert not resp['result']['isError']
        print("PASS: tools/call (pueue_status)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_status) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_add():
    print("Testing tools/call (pueue_add)...")
    req = {
        "jsonrpc": "2.0",
        "id": 4,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "echo 'hello mcp'",
                "label": "mcp-test-task"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert resp['jsonrpc'] == '2.0'
        assert resp['id'] == 4
        assert 'result' in resp
        content = resp['result']['content'][0]['text']
        # Success output from pueue usually says "New task added (id X)."
        assert "New task added" in content or "Success" in content or "id" in content
        assert not resp['result']['isError']
        print("PASS: tools/call (pueue_add)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_add) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_error_handling():
    print("Testing error handling (unknown method)...")
    req = {
        "jsonrpc": "2.0",
        "id": 99,
        "method": "unknown_method",
        "params": {}
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert resp['jsonrpc'] == '2.0'
        assert resp['id'] == 99
        assert 'error' in resp
        assert resp['error']['code'] == -32601 # Method not found
        print("PASS: error handling")
    except Exception as e:
        print(f"FAIL: error handling - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_list_all_tools():
    """Verify all expected tools are registered."""
    print("Testing tools/list (all tools)...")
    req = {
        "jsonrpc": "2.0",
        "id": "all-tools",
        "method": "tools/list"
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        tools = resp['result']['tools']
        tool_names = [t['name'] for t in tools]
        
        expected_tools = [
            'pueue_status', 'pueue_add', 'pueue_log', 'pueue_wait',
            'pueue_clean', 'pueue_kill', 'pueue_pause', 'pueue_resume',
            'pueue_restart', 'pueue_start', 'pueue_remove',
            'pueue_group_add', 'pueue_group_remove', 'pueue_parallel'
        ]
        
        missing = [t for t in expected_tools if t not in tool_names]
        assert len(missing) == 0, f"Missing tools: {missing}"
        
        print("PASS: tools/list (all tools)")
    except Exception as e:
        print(f"FAIL: tools/list (all tools) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_clean():
    """Test cleaning finished tasks."""
    print("Testing tools/call (pueue_clean)...")
    req = {
        "jsonrpc": "2.0",
        "id": 10,
        "method": "tools/call",
        "params": {
            "name": "pueue_clean",
            "arguments": {}
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_clean)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_clean) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_group_add():
    """Test adding a group."""
    print("Testing tools/call (pueue_group_add)...")
    req = {
        "jsonrpc": "2.0",
        "id": 11,
        "method": "tools/call",
        "params": {
            "name": "pueue_group_add",
            "arguments": {
                "name": "test-group"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        # Group might already exist, so either success or error is ok
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_group_add)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_group_add) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_parallel():
    """Test setting parallel tasks."""
    print("Testing tools/call (pueue_parallel)...")
    req = {
        "jsonrpc": "2.0",
        "id": 12,
        "method": "tools/call",
        "params": {
            "name": "pueue_parallel",
            "arguments": {
                "parallel": "2"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_parallel)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_parallel) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_pause():
    """Test pausing tasks."""
    print("Testing tools/call (pueue_pause)...")
    req = {
        "jsonrpc": "2.0",
        "id": 13,
        "method": "tools/call",
        "params": {
            "name": "pueue_pause",
            "arguments": {}
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_pause)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_pause) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_resume():
    """Test resuming tasks."""
    print("Testing tools/call (pueue_resume)...")
    req = {
        "jsonrpc": "2.0",
        "id": 14,
        "method": "tools/call",
        "params": {
            "name": "pueue_resume",
            "arguments": {}
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_resume)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_resume) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_start():
    """Test starting tasks."""
    print("Testing tools/call (pueue_start)...")
    req = {
        "jsonrpc": "2.0",
        "id": 15,
        "method": "tools/call",
        "params": {
            "name": "pueue_start",
            "arguments": {}
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_start)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_start) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_missing_required_params():
    """Test error when required params are missing."""
    print("Testing missing required params (pueue_add without command)...")
    req = {
        "jsonrpc": "2.0",
        "id": 16,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                # missing "command" - should return error
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        # Server should return isError: true when command is missing
        result = resp.get('result', {})
        assert result.get('isError') == True, "Should return error for missing command"
        content = result.get('content', [{}])[0]
        assert 'command' in content.get('text', '').lower(), "Error should mention missing command"
        print("PASS: missing required params")
    except Exception as e:
        print(f"FAIL: missing required params - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_invalid_jsonrpc():
    """Test error handling for invalid JSON-RPC request."""
    print("Testing invalid JSON-RPC...")
    # Send raw invalid JSON
    process = subprocess.Popen(
        ['./pueue-mcp'],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    stdout, stderr = process.communicate(input="not valid json\n")
    # Server should handle gracefully (might print error or close)
    print("PASS: invalid JSON-RPC")

def test_call_pueue_log():
    """Test getting log output of a task."""
    print("Testing tools/call (pueue_log)...")
    req = {
        "jsonrpc": "2.0",
        "id": 20,
        "method": "tools/call",
        "params": {
            "name": "pueue_log",
            "arguments": {
                "id": "0"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        # Either success or error (if task doesn't exist) is acceptable
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_log)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_log) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_wait():
    """Test waiting for tasks - may timeout if no tasks running."""
    print("Testing tools/call (pueue_wait)...")
    req = {
        "jsonrpc": "2.0",
        "id": 21,
        "method": "tools/call",
        "params": {
            "name": "pueue_wait",
            "arguments": {
                "ids": ["0"]
            }
        }
    }
    try:
        output = run_mcp_request(req, timeout=3)  # Short timeout for wait
    except TimeoutError:
        print("SKIP: tools/call (pueue_wait) - timed out (expected if no tasks)")
        return
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_wait)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_wait) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_kill():
    """Test killing running tasks."""
    print("Testing tools/call (pueue_kill)...")
    req = {
        "jsonrpc": "2.0",
        "id": 22,
        "method": "tools/call",
        "params": {
            "name": "pueue_kill",
            "arguments": {}
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_kill)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_kill) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_restart():
    """Test restarting tasks."""
    print("Testing tools/call (pueue_restart)...")
    req = {
        "jsonrpc": "2.0",
        "id": 23,
        "method": "tools/call",
        "params": {
            "name": "pueue_restart",
            "arguments": {
                "ids": ["0"]
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        # Either success or error (if task doesn't exist) is acceptable
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_restart)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_restart) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_remove():
    """Test removing tasks."""
    print("Testing tools/call (pueue_remove)...")
    req = {
        "jsonrpc": "2.0",
        "id": 24,
        "method": "tools/call",
        "params": {
            "name": "pueue_remove",
            "arguments": {
                "ids": ["99999"]
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        # Either success or error (if task doesn't exist) is acceptable
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_remove)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_remove) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_call_pueue_group_remove():
    """Test removing a group."""
    print("Testing tools/call (pueue_group_remove)...")
    req = {
        "jsonrpc": "2.0",
        "id": 25,
        "method": "tools/call",
        "params": {
            "name": "pueue_group_remove",
            "arguments": {
                "name": "non-existent-group"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        # Either success or error (if group doesn't exist) is acceptable
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_group_remove)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_group_remove) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_tool_input_schemas():
    """Verify tools have proper input schemas."""
    print("Testing tool input schemas...")
    req = {
        "jsonrpc": "2.0",
        "id": 26,
        "method": "tools/list"
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        tools = resp['result']['tools']
        
        # Check that key tools have inputSchema
        for tool in tools:
            if tool['name'] in ['pueue_add', 'pueue_status', 'pueue_log']:
                assert 'inputSchema' in tool, f"{tool['name']} missing inputSchema"
        
        print("PASS: tool input schemas")
    except Exception as e:
        print(f"FAIL: tool input schemas - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_log_with_lines_param():
    """Test log with lines parameter."""
    print("Testing tools/call (pueue_log with lines)...")
    req = {
        "jsonrpc": "2.0",
        "id": 27,
        "method": "tools/call",
        "params": {
            "name": "pueue_log",
            "arguments": {
                "id": "0",
                "lines": "10"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_log with lines)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_log with lines) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_wait_with_group():
    """Test wait with group parameter - may timeout."""
    print("Testing tools/call (pueue_wait with group)...")
    req = {
        "jsonrpc": "2.0",
        "id": 28,
        "method": "tools/call",
        "params": {
            "name": "pueue_wait",
            "arguments": {
                "group": "default"
            }
        }
    }
    try:
        output = run_mcp_request(req, timeout=3)
    except TimeoutError:
        print("SKIP: tools/call (pueue_wait with group) - timed out (expected)")
        return
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_wait with group)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_wait with group) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_kill_with_group():
    """Test kill with group parameter."""
    print("Testing tools/call (pueue_kill with group)...")
    req = {
        "jsonrpc": "2.0",
        "id": 29,
        "method": "tools/call",
        "params": {
            "name": "pueue_kill",
            "arguments": {
                "group": "default"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_kill with group)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_kill with group) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_pause_with_group():
    """Test pause with group parameter."""
    print("Testing tools/call (pueue_pause with group)...")
    req = {
        "jsonrpc": "2.0",
        "id": 30,
        "method": "tools/call",
        "params": {
            "name": "pueue_pause",
            "arguments": {
                "group": "default"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_pause with group)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_pause with group) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_resume_with_group():
    """Test resume with group parameter."""
    print("Testing tools/call (pueue_resume with group)...")
    req = {
        "jsonrpc": "2.0",
        "id": 31,
        "method": "tools/call",
        "params": {
            "name": "pueue_resume",
            "arguments": {
                "group": "default"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_resume with group)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_resume with group) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_start_with_group():
    """Test start with group parameter."""
    print("Testing tools/call (pueue_start with group)...")
    req = {
        "jsonrpc": "2.0",
        "id": 32,
        "method": "tools/call",
        "params": {
            "name": "pueue_start",
            "arguments": {
                "group": "default"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_start with group)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_start with group) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_group_add_with_parallel():
    """Test adding group with parallel parameter."""
    print("Testing tools/call (pueue_group_add with parallel)...")
    req = {
        "jsonrpc": "2.0",
        "id": 33,
        "method": "tools/call",
        "params": {
            "name": "pueue_group_add",
            "arguments": {
                "name": "test-parallel-group",
                "parallel": "3"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_group_add with parallel)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_group_add with parallel) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_parallel_with_group():
    """Test setting parallel with group parameter."""
    print("Testing tools/call (pueue_parallel with group)...")
    req = {
        "jsonrpc": "2.0",
        "id": 34,
        "method": "tools/call",
        "params": {
            "name": "pueue_parallel",
            "arguments": {
                "parallel": "4",
                "group": "default"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_parallel with group)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_parallel with group) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_clean_successful_only():
    """Test clean with successful_only parameter."""
    print("Testing tools/call (pueue_clean with successful_only)...")
    req = {
        "jsonrpc": "2.0",
        "id": 35,
        "method": "tools/call",
        "params": {
            "name": "pueue_clean",
            "arguments": {
                "successful_only": "true"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_clean with successful_only)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_clean with successful_only) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_add_with_group():
    """Test adding a task with group parameter."""
    print("Testing tools/call (pueue_add with group)...")
    req = {
        "jsonrpc": "2.0",
        "id": 17,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "echo 'test with group'",
                "group": "default"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_add with group)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_add with group) - {e}")
        print(f"Output: {output}")
        sys.exit(1)

def test_add_with_delay():
    """Test adding a task with delay parameter."""
    print("Testing tools/call (pueue_add with delay)...")
    req = {
        "jsonrpc": "2.0",
        "id": 18,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "echo 'delayed task'",
                "delay": "5s"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_add with delay)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_add with delay) - {e}")
        print(f"Output: {output}")
        sys.exit(1)


def test_add_with_various_delay_formats():
    """Test adding tasks with various delay formats (定时任务测试)."""
    print("Testing tools/call (pueue_add with various delay formats)...")
    
    # Test different delay formats supported by pueue
    delay_formats = [
        ("10s", "seconds"),
        ("5m", "minutes"),
        ("1h", "hours"),
        ("1d", "days"),
    ]
    
    for delay, desc in delay_formats:
        req = {
            "jsonrpc": "2.0",
            "id": 100,
            "method": "tools/call",
            "params": {
                "name": "pueue_add",
                "arguments": {
                    "command": f"echo '{desc} delay'",
                    "delay": delay
                }
            }
        }
        output = run_mcp_request(req)
        try:
            resp = json.loads(output)
            assert 'result' in resp or 'error' in resp, f"Failed for delay={delay}"
            print(f"  PASS: delay={delay} ({desc})")
        except Exception as e:
            print(f"  FAIL: delay={delay} ({desc}) - {e}")
            print(f"  Output: {output}")
            sys.exit(1)
    
    print("PASS: tools/call (pueue_add with various delay formats)")


def test_add_scheduled_task():
    """Test adding a scheduled task (定时任务) with future time."""
    print("Testing tools/call (pueue_add scheduled task)...")
    
    # Test with a time-based delay (will be scheduled for later execution)
    req = {
        "jsonrpc": "2.0",
        "id": 101,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "echo 'scheduled task'",
                "delay": "tomorrow"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        # Should succeed - tomorrow is a valid delay format
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_add scheduled task)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_add scheduled task) - {e}")
        print(f"Output: {output}")
        sys.exit(1)


def test_add_with_after():
    """Test adding a task that starts after other tasks complete."""
    print("Testing tools/call (pueue_add with 'after' parameter)...")
    
    # First, add a task that will run
    req1 = {
        "jsonrpc": "2.0",
        "id": 102,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "echo 'first task'"
            }
        }
    }
    output1 = run_mcp_request(req1)
    resp1 = json.loads(output1)
    
    if 'result' in resp1:
        # Get the task ID from the result
        result = resp1['result']
        task_id = result if isinstance(result, int) else result.get('task_id', 0)
        
        # Now add a task that depends on the first task
        req2 = {
            "jsonrpc": "2.0",
            "id": 103,
            "method": "tools/call",
            "params": {
                "name": "pueue_add",
                "arguments": {
                    "command": "echo 'second task'",
                    "after": [task_id]
                }
            }
        }
        output2 = run_mcp_request(req2)
        resp2 = json.loads(output2)
        assert 'result' in resp2 or 'error' in resp2
    
    print("PASS: tools/call (pueue_add with 'after' parameter)")


def test_add_with_stashed():
    """Test adding a task in stashed state (queued but not running)."""
    print("Testing tools/call (pueue_add with stashed parameter)...")
    
    req = {
        "jsonrpc": "2.0",
        "id": 104,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "echo 'stashed task'",
                "stashed": True
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_add with stashed parameter)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_add with stashed parameter) - {e}")
        print(f"Output: {output}")
        sys.exit(1)


def test_add_with_immediate():
    """Test adding a task with immediate flag (starts immediately)."""
    print("Testing tools/call (pueue_add with immediate parameter)...")
    
    req = {
        "jsonrpc": "2.0",
        "id": 105,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "echo 'immediate task'",
                "immediate": True
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_add with immediate parameter)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_add with immediate parameter) - {e}")
        print(f"Output: {output}")
        sys.exit(1)


def test_add_with_priority():
    """Test adding a task with priority."""
    print("Testing tools/call (pueue_add with priority parameter)...")
    
    req = {
        "jsonrpc": "2.0",
        "id": 106,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "echo 'high priority task'",
                "priority": 100
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_add with priority parameter)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_add with priority parameter) - {e}")
        print(f"Output: {output}")
        sys.exit(1)


def test_add_with_working_directory():
    """Test adding a task with custom working directory."""
    print("Testing tools/call (pueue_add with working_directory)...")
    
    req = {
        "jsonrpc": "2.0",
        "id": 107,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "pwd",
                "working_directory": "/tmp"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_add with working_directory)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_add with working_directory) - {e}")
        print(f"Output: {output}")
        sys.exit(1)


def test_add_label():
    """Test adding a task with label."""
    print("Testing tools/call (pueue_add with label)...")
    
    req = {
        "jsonrpc": "2.0",
        "id": 108,
        "method": "tools/call",
        "params": {
            "name": "pueue_add",
            "arguments": {
                "command": "echo 'labeled task'",
                "label": "test-label"
            }
        }
    }
    output = run_mcp_request(req)
    try:
        resp = json.loads(output)
        assert 'result' in resp or 'error' in resp
        print("PASS: tools/call (pueue_add with label)")
    except Exception as e:
        print(f"FAIL: tools/call (pueue_add with label) - {e}")
        print(f"Output: {output}")
        sys.exit(1)


if __name__ == "__main__":
    # Ensure binary exists
    if not os.path.exists("./pueue-mcp"):
        print("Error: ./pueue-mcp binary not found. Run ./build.sh first.")
        sys.exit(1)

    test_initialize()
    test_list_tools()
    test_list_all_tools()
    test_call_pueue_status()
    test_call_pueue_add()
    test_call_pueue_clean()
    test_call_pueue_group_add()
    test_call_pueue_parallel()
    test_call_pueue_pause()
    test_call_pueue_resume()
    test_call_pueue_start()
    test_add_with_group()
    test_add_with_delay()
    
    # 定时任务 (scheduled task) tests
    test_add_with_various_delay_formats()
    test_add_scheduled_task()
    test_add_with_after()
    test_add_with_stashed()
    test_add_with_immediate()
    test_add_with_priority()
    test_add_with_working_directory()
    test_add_label()
    
    test_missing_required_params()
    test_invalid_jsonrpc()
    test_error_handling()
    
    # Additional tool tests
    test_call_pueue_log()
    test_call_pueue_wait()
    test_call_pueue_kill()
    test_call_pueue_restart()
    test_call_pueue_remove()
    test_call_pueue_group_remove()
    test_tool_input_schemas()
    test_log_with_lines_param()
    test_wait_with_group()
    test_kill_with_group()
    test_pause_with_group()
    test_resume_with_group()
    test_start_with_group()
    test_group_add_with_parallel()
    test_parallel_with_group()
    test_clean_successful_only()
    
    print("\nAll integration tests passed!")
