import { afterAll, beforeAll, expect, test, jest } from 'bun:test'
import { existsSync, rmSync } from 'node:fs'
import { join } from 'node:path'
import { spawnSync } from 'node:child_process'

const rootDir = join(import.meta.dir, '..')
const binaryName =
  process.platform === 'win32'
    ? 'pueue-mcp-real-test.exe'
    : 'pueue-mcp-real-test'
const binaryPath = join(rootDir, binaryName)
const createdTaskIds: number[] = []

function runCommand(command: string, args: string[], timeout = 20_000) {
  const result = spawnSync(command, args, {
    cwd: rootDir,
    encoding: 'utf8',
    windowsHide: true,
    timeout
  })

  if (result.error) {
    throw result.error
  }

  return {
    stdout: result.stdout?.trim() ?? '',
    stderr: result.stderr?.trim() ?? '',
    status: result.status ?? 0
  }
}

function ensureBuild() {
  const build = runCommand('v', ['-o', binaryName, 'main.v'], 60_000)
  if (build.status !== 0) {
    throw new Error(
      `Failed to build test binary:\n${build.stderr || build.stdout}`
    )
  }
  expect(existsSync(binaryPath)).toBe(true)
}

function sendMcpRequest(request: unknown, timeout = 20_000) {
  const result = spawnSync(binaryPath, [], {
    cwd: rootDir,
    encoding: 'utf8',
    windowsHide: true,
    timeout,
    input: `${JSON.stringify(request)}\n`
  })

  if (result.error) {
    throw result.error
  }

  const stdout = result.stdout?.trim() ?? ''
  const stderr = result.stderr?.trim() ?? ''

  if (!stdout) {
    throw new Error(`MCP request returned no stdout. stderr: ${stderr}`)
  }

  const jsonLine = stdout
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean)
    .at(-1)

  if (!jsonLine) {
    throw new Error(`Unable to locate JSON response in stdout: ${stdout}`)
  }

  return JSON.parse(jsonLine)
}

function callTool(
  name: string,
  arguments_: Record<string, unknown> = {},
  id: string | number = crypto.randomUUID()
) {
  return sendMcpRequest({
    jsonrpc: '2.0',
    id,
    method: 'tools/call',
    params: {
      name,
      arguments: arguments_
    }
  })
}

function toolText(response: any) {
  return response?.result?.content?.[0]?.text ?? ''
}

function extractTaskId(text: string) {
  const match = text.match(/id\s+(\d+)/i)
  if (!match) {
    throw new Error(`Unable to extract task id from response: ${text}`)
  }
  return Number.parseInt(match[1], 10)
}

function shellEchoCommand(message: string) {
  return process.platform === 'win32'
    ? `cmd /c echo ${message}`
    : `sh -lc 'echo ${message}'`
}

function shellExitCommand(exitCode: number) {
  return process.platform === 'win32'
    ? `cmd /c exit ${exitCode}`
    : `sh -lc 'exit ${exitCode}'`
}

beforeAll(() => {
  ensureBuild()
})

afterAll(() => {
  try {
    if (createdTaskIds.length > 0) {
      callTool('pueue_remove', { ids: createdTaskIds }, 'cleanup-remove')
    }
  } catch {
    // best-effort cleanup only
  }

  try {
    callTool('pueue_clean', { successful_only: true }, 'cleanup-clean')
  } catch {
    // best-effort cleanup only
  }

  if (existsSync(binaryPath)) {
    rmSync(binaryPath, { force: true })
  }
})

// Increase default test timeout to 30 seconds
jest.setTimeout(30000)

test('pueue-mcp real functionality works end-to-end', () => {
  const initialize = sendMcpRequest({
    jsonrpc: '2.0',
    id: 1,
    method: 'initialize',
    params: {
      protocolVersion: '2024-11-05',
      clientInfo: { name: 'bun-real-test', version: '1.0.0' },
      capabilities: {}
    }
  })

  expect(initialize.result.protocolVersion).toBe('2024-11-05')
  expect(initialize.result.capabilities.logging.setLevel).toBe('true')
  expect(initialize.result.serverInfo.name).toBe('pueue-mcp-v')

  const setLevel = sendMcpRequest({
    jsonrpc: '2.0',
    id: 'log-level',
    method: 'logging/setLevel',
    params: { level: 'info' }
  })

  expect(setLevel.id).toBe('log-level')
  expect(setLevel.result.level).toBe('info')

  const tools = sendMcpRequest({ jsonrpc: '2.0', id: 2, method: 'tools/list' })
  const toolNames = tools.result.tools.map(
    (tool: { name: string }) => tool.name
  )
  expect(toolNames).toContain('pueue_start_daemon')
  expect(toolNames).toContain('pueue_add')
  expect(toolNames).toContain('pueue_status')
  expect(toolNames).toContain('pueue_log')

  const daemon = callTool('pueue_start_daemon', {}, 3)
  expect(daemon.result.isError).toBe(false)
  expect(toolText(daemon)).toMatch(/Daemon/i)

  const successMarker = `bun-real-success-${Date.now()}`
  const addSuccess = callTool(
    'pueue_add',
    {
      command: shellEchoCommand(successMarker),
      label: `bun-real-success-${Date.now()}`
    },
    4
  )
  expect(addSuccess.result.isError).toBe(false)
  const successTaskId = extractTaskId(toolText(addSuccess))
  createdTaskIds.push(successTaskId)

  const waitSuccess = callTool('pueue_wait', { ids: [successTaskId] }, 5)
  expect(waitSuccess.result.isError).toBe(false)

  const successLog = callTool('pueue_log', { id: successTaskId }, 6)
  expect(successLog.result.isError).toBe(false)
  expect(toolText(successLog)).toContain(successMarker)

  const failedExitCode = 23
  const failureCommand = shellExitCommand(failedExitCode)
  const addFailure = callTool(
    'pueue_add',
    {
      command: failureCommand,
      label: `bun-real-fail-${Date.now()}`
    },
    7
  )
  expect(addFailure.result.isError).toBe(false)
  const failedTaskId = extractTaskId(toolText(addFailure))
  createdTaskIds.push(failedTaskId)

  const waitFailure = callTool('pueue_wait', { ids: [failedTaskId] }, 8)
  expect(waitFailure.result.isError).toBe(false)

  const status = callTool('pueue_status', {}, 9)
  expect(status.result.isError).toBe(false)
  const statusText = toolText(status)
  expect(statusText).toContain(`[${failedTaskId}] failed`)
  expect(statusText).toContain(failureCommand)
  expect(statusText).toMatch(/Exit Code: \d+/)

  const cleanSuccess = callTool('pueue_clean', { successful_only: true }, 10)
  expect(cleanSuccess.result.isError).toBe(false)
})
