# Spec 04 — Container Infrastructure

> Docker container management, lifecycle, and session persistence.
> Dependencies: 03-Agent System (needs CLI backend strategy from wave-3).

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Docker Container Manager | ContainerManager service, Docker config files (docker.php, docker-hosts.php), container start/stop/remove operations |
| 2 | Lifecycle & Sessions | Container lifecycle management (warm → dead), session volume management, cleanup scheduled commands |

## Dependencies on Other Specs

- **03-Agent System** (wave-3): ContainerManager needs CLI backend strategy to know which CLI to invoke and how to build commands. Container setup (volume mounts, env vars) depends on the resolved backend.

## Docker Image Reference

Pre-built universal image at `~/Code/kodizm.com/docker/`:
- Ubuntu 24.04 base
- 9 language runtimes (Python, Node, Bun, Rust, Go, Ruby, PHP, Java, Flutter)
- Claude Code CLI + OpenCode CLI pre-installed
- Non-root `agent` user (UID 1001) via gosu
- tini as init process
- PostgreSQL 17, Redis available inside container
- LSP servers, linters, formatters included

## Container Model

This is **not** a database model. Containers are runtime-managed ephemeral resources:
- Created on demand when an agent run starts
- Tracked via `container_name` field on `TaskRun` model
- Warm state tracked in Redis (key: `warm:{task_run_id}`)
- No `containers` DB table — Docker daemon is the source of truth for running containers
- Session volumes persist on disk at `{session_volume_base}/{taskRunId}/`

## Configuration

### config/docker.php
```php
return [
    'image' => 'kodizm/agent-universal:latest',
    'warm_timeout' => 300,       // seconds (5 min) — container stays alive after question
    'session_max_age' => 86400,  // seconds (24h) — session volume cleaned up after dead
    'idle_timeout' => 300,       // seconds — container killed if no activity
    'max_run_duration' => 3600,  // seconds (1h) — hard wall-clock limit per run
    'memory_limit' => '4g',
    'cpu_limit' => '2',
    'session_volume_base' => '/var/kodizm/sessions',
    'workspace_volume_base' => '/var/kodizm/workspaces',
];
```

### config/docker-hosts.php
```php
return [
    'hosts' => [
        'local' => [
            'docker_host' => null,              // local socket
            'mcp_endpoint' => env('APP_URL'),
            'tls_verify' => false,
        ],
        'remote-1' => [
            'docker_host' => 'tcp://192.168.1.100:2376',
            'mcp_endpoint' => 'http://192.168.1.100:8080',
            'tls_verify' => true,
        ],
    ],
];
```

## Execution Model

Containers use a long-lived entrypoint pattern:
```
docker run -d --entrypoint sleep {image} infinity
```
Then commands are executed inside:
```
docker exec -i {container} {command}
```

This allows multiple commands to run in the same container context and enables the warm phase (container stays alive for follow-up interactions).

## Container Naming Convention

```
kodizm-{taskRunId}-{short_hash}
```

Example: `kodizm-42-a1b2c3`

## Security

- `--security-opt no-new-privileges` — prevent privilege escalation
- `--cap-drop ALL` — drop all Linux capabilities
- Container runs as non-root `agent` user (UID 1001) via gosu (per existing Docker image)
- Resource limits: memory (4GB), CPU (2 cores) — configurable via docker.php

## Business Rules

### Container Lifecycle Timings
```
warm_timeout:     300s  (5 min)  — container alive after question
session_max_age:  86400s (24h)   — session volume cleaned up
idle_timeout:     300s           — container killed if no activity
max_run_duration: 3600s (1h)    — hard wall-clock limit per run
```

Note: `idle_timeout` is suspended when TaskRun status is `waiting_for_input`. It only applies to active execution with no output.

### Concurrency
- Max concurrent runs per project: 3 (configurable)
- Max concurrent runs per team: 10 (configurable)
- Same task: max 1 active run
