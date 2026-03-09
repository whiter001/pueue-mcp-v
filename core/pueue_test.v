module core

import json

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
        "      \"status\": \"Running\",\n" +
        "      \"label\": \"test-task\",\n" +
        "      \"enqueue_time\": \"2024-01-01T12:00:00Z\",\n" +
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

    resp := json.decode(StatusResponse, json_output) or { panic(err) }
    assert resp.tasks.len == 1
    assert resp.groups.len == 1
    assert resp.groups['default'].parallel_tasks == 5
}
