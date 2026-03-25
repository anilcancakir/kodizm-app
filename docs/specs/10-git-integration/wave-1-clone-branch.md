# Spec 10, Wave 1 — Clone & Branch

> GitService for repository cloning, feature branch creation, and SSH key injection into agent containers.
> Dependencies: 02-wave-2 (projects with repository_url and SSH keys), 04-wave-1 (ContainerManager).

## Deliverables

1. GitService — clone, pull, branch creation, workspace management
2. SSH key injection into containers (file mount + GIT_SSH_COMMAND)
3. Feature branch creation per task
4. Workspace caching strategy
5. Integration with ContainerManager (volume mount)
6. Configuration file for git settings
7. Tests for GitService operations
8. **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## 1. GitService

Central service for all git operations related to agent runs.

### Interface

```
GitService::prepareWorkspace(Project $project, Task $task): WorkspaceResult
GitService::cleanupWorkspace(Project $project): void
```

### WorkspaceResult

```
WorkspaceResult {
    path: string,              // Absolute path to workspace on host
    branch: string,            // Branch name (e.g., 'feature/task-45')
    isClone: bool,             // true if freshly cloned, false if pulled
}
```

### prepareWorkspace Logic

```
1. Determine workspace path: config('git.workspace_base')/{project_id}/repo
2. IF workspace path does NOT exist (first run for this project):
   a. mkdir -p {workspace_base}/{project_id}
   b. Write project's ssh_private_key to {workspace_base}/{project_id}/id_rsa
   c. chmod 600 on the key file
   d. git clone {project.repository_url} {workspace_path}
      with GIT_SSH_COMMAND="ssh -i {key_path} -o StrictHostKeyChecking=no"
   e. isClone = true
3. ELSE (repo already cached):
   a. cd {workspace_path}
   b. git fetch origin
   c. git checkout {project.default_branch}
   d. git reset --hard origin/{project.default_branch}
   e. isClone = false
4. Create feature branch:
   a. branch_name = config('git.branch_pattern', 'feature/task-{id}')
      with {id} replaced by task.id
   b. git checkout -b {branch_name}
   c. Store branch_name on task.branch_name (if not already set)
5. Return WorkspaceResult { path, branch, isClone }
```

### cleanupWorkspace Logic

```
1. Determine workspace path: config('git.workspace_base')/{project_id}
2. rm -rf {workspace_path}
3. Log cleanup
```

### Error Handling

| Error | Behavior |
|-------|----------|
| Clone fails (invalid URL) | Throw `GitCloneException` with stderr output |
| Clone fails (SSH auth) | Throw `GitAuthException` — likely deploy key not configured |
| Branch already exists | `git checkout {branch}` (reuse existing branch) |
| Fetch fails (network) | Throw `GitFetchException` — transient, retryable |
| No SSH key on project | Throw `GitAuthException` — project.ssh_private_key is null |

## 2. SSH Key Injection

### Host Setup

When preparing the workspace, the SSH private key is written to a file:

```
{workspace_base}/{project_id}/id_rsa     # Private key file (chmod 600)
```

### Container Mount

The SSH key is mounted into the container as a read-only volume:

```
-v {workspace_base}/{project_id}/id_rsa:/home/agent/.ssh/id_rsa:ro
```

### GIT_SSH_COMMAND

Set as environment variable on the container:

```
GIT_SSH_COMMAND=ssh -i /home/agent/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
```

This allows the agent to push commits from inside the container without SSH key configuration.

### Security

- Key file permissions: `600` (owner read/write only)
- Container mount: read-only (`:ro`)
- Key is the project's `ssh_private_key` (encrypted at rest in DB, decrypted only when writing to file)
- `StrictHostKeyChecking=no` avoids interactive prompts for new hosts
- `UserKnownHostsFile=/dev/null` avoids persisting host keys

## 3. Feature Branch

### Branch Naming

- **Default pattern**: `feature/task-{id}`
- **Configurable**: `config('git.branch_pattern')` with `{id}` placeholder
- **Examples**: `feature/task-45`, `kodizm/task-123`

### Branch Strategy

```
main (or master, per project.default_branch)
  │
  ├── feature/task-45    ← Agent works here
  ├── feature/task-46    ← Different task
  └── feature/task-47    ← Different task
```

- Each task gets its own branch from `project.default_branch`
- If branch already exists (retry/resume), checkout existing branch
- Agent (Claude Code) handles all commits and pushes
- Post-MVP: auto-create PR via GitHub API after run completion

### Branch Name Storage

- Stored on `tasks.branch_name` when first created
- Subsequent runs for the same task reuse the same branch

## 4. Workspace Volume Mount

### Container Integration

When ContainerManager creates a container for an agent run, GitService provides the workspace path to mount:

```
docker run -d \
  -v {workspace_path}:/workspace \
  -v {workspace_base}/{project_id}/id_rsa:/home/agent/.ssh/id_rsa:ro \
  -e GIT_SSH_COMMAND="ssh -i /home/agent/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
  -w /workspace \
  kodizm-agent:latest \
  sleep infinity
```

- Workspace mounted at `/workspace` inside container
- Working directory set to `/workspace`
- Agent user (UID 1001) must have write access to `/workspace`

### Ownership

After clone/pull, ensure workspace files are owned by the agent user (UID 1001):

```bash
chown -R 1001:1001 {workspace_path}
```

This ensures the agent process inside the container can read/write all files.

## 5. Configuration

```php
// config/git.php
return [
    'workspace_base' => env('GIT_WORKSPACE_BASE', storage_path('workspaces')),
    'branch_pattern' => env('GIT_BRANCH_PATTERN', 'feature/task-{id}'),
    'clone_timeout' => env('GIT_CLONE_TIMEOUT', 300),   // seconds
    'fetch_timeout' => env('GIT_FETCH_TIMEOUT', 60),    // seconds
];
```

| Key | Default | Description |
|-----|---------|-------------|
| `workspace_base` | `storage/workspaces` | Base directory for cached repos |
| `branch_pattern` | `feature/task-{id}` | Feature branch naming pattern |
| `clone_timeout` | 300 | Max seconds for git clone |
| `fetch_timeout` | 60 | Max seconds for git fetch |

## 6. File Structure

```
app/Services/
├── GitService.php                # Main git operations service
└── Dto/
    └── WorkspaceResult.php       # Return type for prepareWorkspace

app/Exceptions/
├── GitCloneException.php
├── GitFetchException.php
└── GitAuthException.php

config/
└── git.php                       # Git configuration
```

## Acceptance Criteria

### Clone (First Run)
- **Given** a project with a valid `repository_url` and `ssh_private_key`, **when** `prepareWorkspace()` is called for the first time, **then** the repository is cloned into `{workspace_base}/{project_id}/repo` and `isClone` is true.
- **Given** the clone completes, **when** the workspace is inspected, **then** it contains the repository files and is on the feature branch `feature/task-{id}`.
- **Given** a project with no `ssh_private_key`, **when** `prepareWorkspace()` is called, **then** `GitAuthException` is thrown.
- **Given** an invalid `repository_url`, **when** `prepareWorkspace()` is called, **then** `GitCloneException` is thrown with stderr output.

### Pull (Subsequent Runs)
- **Given** a workspace already exists for the project, **when** `prepareWorkspace()` is called, **then** `git fetch origin` is run and the workspace is updated to the latest `default_branch` before creating the feature branch, with `isClone` is false.
- **Given** a cached workspace, **when** a new task creates a branch, **then** the branch is created from the latest `origin/{default_branch}`.

### Feature Branch
- **Given** task ID 45, **when** `prepareWorkspace()` is called, **then** the feature branch `feature/task-45` is created and checked out.
- **Given** task ID 45 with an existing branch `feature/task-45`, **when** `prepareWorkspace()` is called again (resume/retry), **then** the existing branch is checked out (no error).
- **Given** `GIT_BRANCH_PATTERN=kodizm/task-{id}`, **when** `prepareWorkspace()` is called for task 45, **then** branch name is `kodizm/task-45`.
- **Given** the branch is created, **when** `task.branch_name` is checked, **then** it stores the branch name.

### SSH Key Injection
- **Given** a project's SSH private key, **when** the workspace is prepared, **then** the key is written to `{workspace_base}/{project_id}/id_rsa` with permissions 600.
- **Given** a container is started, **when** the mounts are inspected, **then** the SSH key is mounted at `/home/agent/.ssh/id_rsa` as read-only.
- **Given** a container is started, **when** the environment is inspected, **then** `GIT_SSH_COMMAND` is set to use the mounted key with `StrictHostKeyChecking=no`.

### Workspace Volume
- **Given** a prepared workspace, **when** a container is started, **then** the workspace is mounted at `/workspace` inside the container.
- **Given** the workspace files, **when** ownership is checked, **then** all files are owned by UID 1001 (agent user).

### Cleanup
- **Given** a workspace exists for project ID 12, **when** `cleanupWorkspace()` is called, **then** the entire `{workspace_base}/12` directory is removed.
- **Given** a workspace does not exist, **when** `cleanupWorkspace()` is called, **then** no error is thrown (idempotent).

### Timeouts
- **Given** `GIT_CLONE_TIMEOUT=300`, **when** a clone takes longer than 300 seconds, **then** the process is killed and `GitCloneException` is thrown.
- **Given** `GIT_FETCH_TIMEOUT=60`, **when** a fetch takes longer than 60 seconds, **then** the process is killed and `GitFetchException` is thrown.
