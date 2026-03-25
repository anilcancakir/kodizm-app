# Wave 1 — Docker Container Manager

> Spec: 04-Container Infrastructure
> Dependencies: 03-wave-3 (CLI backend strategy — needs to know which CLI backend to configure containers for)

## Deliverables

- [ ] `ContainerManager` service class
- [ ] `config/docker.php` config file
- [ ] `config/docker-hosts.php` config file
- [ ] Container start operation (create + run)
- [ ] Container stop operation
- [ ] Container remove operation
- [ ] Container exists/status check
- [ ] Feature tests for ContainerManager
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## ContainerManager Service

`App\Services\ContainerManager`

### Public Methods

```php
public function start(TaskRun $taskRun, array $volumeMounts, array $envVars): string; // returns container name
public function stop(string $containerName): bool;
public function remove(string $containerName): bool;
public function exists(string $containerName): bool;
public function exec(string $containerName, string $command): Process; // returns Symfony Process (for streaming)
public function inspect(string $containerName): ?array; // docker inspect, null if not found
```

### Container Start Flow

```
ContainerManager::start($taskRun, $volumeMounts, $envVars):
  1. Generate container name: kodizm-{taskRun->id}-{short_hash}
  2. Build docker run command:
     docker run -d \
       --name {containerName} \
       --entrypoint sleep \
       --security-opt no-new-privileges \
       --cap-drop ALL \
       --memory {config('docker.memory_limit')} \
       --cpus {config('docker.cpu_limit')} \
       -v {workspace_path}:/workspace \
       -v {session_volume_path}/claude:/home/agent/.claude/projects \
       -v {claude_md_path}:/workspace/CLAUDE.md:ro \
       -e ANTHROPIC_API_KEY={api_key} \
       -e KODIZM_MCP_TOKEN={mcp_token} \
       -e KODIZM_MCP_ENDPOINT={mcp_endpoint} \
       {config('docker.image')} \
       infinity
  3. Execute docker run via Process
  4. Verify container started (docker inspect)
  5. Update TaskRun: container_name = containerName
  6. Return containerName
```

### Container Naming Convention

```
kodizm-{taskRunId}-{short_hash}
```

`short_hash` = first 6 chars of `md5(taskRunId . microtime())`. Ensures uniqueness even if a task run's container is recreated (dead → resume scenario).

### Docker Execution Model

Containers use a long-lived sleep entrypoint:
```bash
docker run -d --entrypoint sleep {image} infinity
```

Then CLI commands are executed inside the running container:
```bash
docker exec -i {container} {command}
```

This pattern allows:
- Multiple sequential commands in the same container
- Warm phase: container stays alive for Q&A interaction
- Volume state persists across exec calls

### Volume Mounts

| Host Path | Container Path | Purpose |
|-----------|---------------|---------|
| `{workspace_volume_base}/{taskRunId}/` | `/workspace` | Git repo / working directory |
| `{session_volume_base}/{taskRunId}/claude/` | `/home/agent/.claude/projects` | Claude Code session persistence |
| Generated CLAUDE.md file | `/workspace/CLAUDE.md` | Agent persona + project context (read-only) |

**Session volume paths by CLI backend** (MVP: Claude Code only):
- Claude Code: `{session_volume_base}/{taskRunId}/claude:/home/agent/.claude/projects`
- OpenCode (post-MVP): `{session_volume_base}/{taskRunId}/opencode:/home/agent/.local/share/opencode`

Note: Container runs as `agent` user (UID 1001) via gosu (per existing Docker image). All paths use `/home/agent/`.

### Environment Variables Injected

| Env Var | Value | Purpose |
|---------|-------|---------|
| `ANTHROPIC_API_KEY` | Resolved API key from token rotation | Claude Code authentication |
| `KODIZM_MCP_TOKEN` | Signed JWT for this task run | MCP server authentication |
| `KODIZM_MCP_ENDPOINT` | `{docker_host.mcp_endpoint}/api/mcp` | MCP server URL |

### Security Flags

```bash
--security-opt no-new-privileges   # prevent privilege escalation inside container
--cap-drop ALL                     # drop all Linux capabilities
```

### Resource Limits

```bash
--memory {config('docker.memory_limit')}   # default: 4g
--cpus {config('docker.cpu_limit')}         # default: 2
```

Configurable per deployment via `config/docker.php`.

## Config Files

### config/docker.php

```php
<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Docker Image
    |--------------------------------------------------------------------------
    */
    'image' => env('DOCKER_IMAGE', 'kodizm/agent-universal:latest'),

    /*
    |--------------------------------------------------------------------------
    | Container Lifecycle Timings
    |--------------------------------------------------------------------------
    */
    'warm_timeout' => (int) env('DOCKER_WARM_TIMEOUT', 300),
    'session_max_age' => (int) env('DOCKER_SESSION_MAX_AGE', 86400),
    'idle_timeout' => (int) env('DOCKER_IDLE_TIMEOUT', 300),
    'max_run_duration' => (int) env('DOCKER_MAX_RUN_DURATION', 3600),

    /*
    |--------------------------------------------------------------------------
    | Resource Limits
    |--------------------------------------------------------------------------
    */
    'memory_limit' => env('DOCKER_MEMORY_LIMIT', '4g'),
    'cpu_limit' => env('DOCKER_CPU_LIMIT', '2'),

    /*
    |--------------------------------------------------------------------------
    | Volume Paths
    |--------------------------------------------------------------------------
    */
    'session_volume_base' => env('DOCKER_SESSION_VOLUME_BASE', '/var/kodizm/sessions'),
    'workspace_volume_base' => env('DOCKER_WORKSPACE_VOLUME_BASE', '/var/kodizm/workspaces'),
];
```

### config/docker-hosts.php

```php
<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Docker Hosts
    |--------------------------------------------------------------------------
    | Config-based, not DB. MVP: local only.
    | Remote hosts are for horizontal scaling (post-MVP).
    */
    'default' => env('DOCKER_HOST_DEFAULT', 'local'),

    'hosts' => [
        'local' => [
            'docker_host' => null,              // local Docker socket
            'mcp_endpoint' => env('APP_URL'),
            'tls_verify' => false,
        ],
        // Example remote host (post-MVP):
        // 'remote-1' => [
        //     'docker_host' => 'tcp://192.168.1.100:2376',
        //     'mcp_endpoint' => 'http://192.168.1.100:8080',
        //     'tls_verify' => true,
        // ],
    ],
];
```

## Acceptance Criteria

### Container Start

**Given** a TaskRun with a valid agent role and resolved token,
**When** `ContainerManager::start()` is called with volume mounts and env vars,
**Then** a Docker container is created with the correct name pattern `kodizm-{id}-{hash}`, the correct image, security flags, resource limits, volume mounts, and environment variables, and the container name is stored on the TaskRun.

**Given** a TaskRun where the Docker image is not available locally,
**When** `ContainerManager::start()` is called,
**Then** an exception is thrown with a descriptive error message (do not auto-pull in production).

**Given** a TaskRun where Docker daemon is unreachable,
**When** `ContainerManager::start()` is called,
**Then** an exception is thrown and the TaskRun status is not modified.

### Container Stop

**Given** a running container name,
**When** `ContainerManager::stop()` is called,
**Then** the container is stopped (docker stop) and the method returns true.

**Given** a non-existent container name,
**When** `ContainerManager::stop()` is called,
**Then** the method returns false (idempotent, no exception).

### Container Remove

**Given** a stopped container name,
**When** `ContainerManager::remove()` is called,
**Then** the container is removed (docker rm) and the method returns true.

**Given** a running container name,
**When** `ContainerManager::remove()` is called,
**Then** the container is force-removed (docker rm -f) and the method returns true.

### Container Exec

**Given** a running container and a valid command string,
**When** `ContainerManager::exec()` is called,
**Then** a Symfony Process is returned configured with `docker exec -i {container} {command}`, ready for streaming stdout.

**Given** a non-existent container name,
**When** `ContainerManager::exec()` is called,
**Then** an exception is thrown.

### Container Exists

**Given** a running container name,
**When** `ContainerManager::exists()` is called,
**Then** it returns true.

**Given** a stopped or non-existent container name,
**When** `ContainerManager::exists()` is called,
**Then** it returns false.

### Config Files

**Given** the application is bootstrapped,
**When** `config('docker.image')` is accessed,
**Then** it returns the configured Docker image name.

**Given** the application is bootstrapped,
**When** `config('docker-hosts.hosts.local')` is accessed,
**Then** it returns the local Docker host configuration array.

## Implementation Notes

- Use `Symfony\Component\Process\Process` for Docker CLI interaction.
- All Docker operations go through the CLI (`docker run`, `docker stop`, `docker rm`, `docker exec`, `docker inspect`). No Docker API SDK needed for MVP.
- `exec()` returns an unstarted Process — the caller (AgentRunner) starts it and streams stdout.
- Container name uniqueness is guaranteed by the hash component.
- For tests: mock the Process class or use a `ContainerManager` interface with a fake implementation.
