module core

fn test_task_status_variants() {
    // sanity: enum values are distinct
    assert TaskStatus.running != TaskStatus.failed
    assert TaskStatus.queued != TaskStatus.success
}

fn test_parse_status_json() {
    json_output := "{\n" +
        "  \"tasks\": {\n" +
        "    \"0\": {\n" +
        "      \"id\": 0,\n" +
        "      \"command\": \"sleep 60\",\n" +
        "      \"path\": \"/home/user\",\n" +
        "      \"status\": {\n" +
        "        \"Running\": {\n" +
        "          \"enqueued_at\": \"2024-01-01T12:00:00Z\",\n" +
        "          \"start\": \"2024-01-01T12:00:01Z\"\n" +
        "        }\n" +
        "      },\n" +
        "      \"label\": \"test-task\",\n" +
        "      \"group\": \"default\"\n" +
        "    }\n" +
        "  },\n" +
        "  \"groups\": {\n" +
        "    \"default\": {\n" +
        "      \"status\": \"Running\",\n" +
        "      \"parallel_tasks\": 5\n" +
        "    }\n" +
        "  }\n" +
        "}\n"

    resp := parse_status_response(json_output) or { panic(err) }
    assert resp.tasks.len == 1
    assert resp.groups.len == 1
    assert resp.groups['default'].parallel_tasks == 5
    assert resp.tasks['0'].status == TaskStatus.running
}

fn test_parse_done_failed_status_json() {
    json_output := "{\n" +
        "  \"tasks\": {\n" +
        "    \"7\": {\n" +
        "      \"id\": 7,\n" +
        "      \"command\": \"cmd /c exit 7\",\n" +
        "      \"path\": \"D:/work/github/pueue-mcp-v\",\n" +
        "      \"status\": {\n" +
        "        \"Done\": {\n" +
        "          \"result\": {\n" +
        "            \"Failed\": 7\n" +
        "          }\n" +
        "        }\n" +
        "      },\n" +
        "      \"label\": \"failed-task\",\n" +
        "      \"group\": \"default\"\n" +
        "    }\n" +
        "  },\n" +
        "  \"groups\": {\n" +
        "    \"default\": {\n" +
        "      \"status\": \"Running\",\n" +
        "      \"parallel_tasks\": 5\n" +
        "    }\n" +
        "  }\n" +
        "}\n"

    resp := parse_status_response(json_output) or { panic(err) }
    assert resp.tasks.len == 1
    assert resp.tasks['7'].status == TaskStatus.failed
    assert resp.tasks['7'].exit_code or { 0 } == 7
}

fn test_parse_done_success_status_json() {
    json_output := "{\n" +
        "  \"tasks\": {\n" +
        "    \"8\": {\n" +
        "      \"id\": 8,\n" +
        "      \"command\": \"echo ok\",\n" +
        "      \"path\": \"D:/work/github/pueue-mcp-v\",\n" +
        "      \"status\": {\n" +
        "        \"Done\": {\n" +
        "          \"result\": \"Success\"\n" +
        "        }\n" +
        "      },\n" +
        "      \"label\": \"success-task\",\n" +
        "      \"group\": \"default\"\n" +
        "    }\n" +
        "  },\n" +
        "  \"groups\": {\n" +
        "    \"default\": {\n" +
        "      \"status\": \"Running\",\n" +
        "      \"parallel_tasks\": 5\n" +
        "    }\n" +
        "  }\n" +
        "}\n"

    resp := parse_status_response(json_output) or { panic(err) }
    assert resp.tasks.len == 1
    assert resp.tasks['8'].status == TaskStatus.success
}
