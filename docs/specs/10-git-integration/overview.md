# Spec 10 — Git Integration

> Repository cloning, feature branch creation, and SSH key injection for agent containers.
> Dependencies: 02 (Project Management — projects with repository_url and SSH keys), 04 (Container Infrastructure — Docker container lifecycle).

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Clone & Branch | GitService, repo clone into container workspace, feature branch creation, SSH key injection |

## Dependencies on Other Specs

| Spec | Why |
|------|-----|
| 02 — Project Management (wave 2) | Projects have `repository_url`, `ssh_private_key`, `ssh_public_key`, `default_branch` |
| 04 — Container Infrastructure (wave 1) | ContainerManager creates and manages Docker containers; GitService integrates with container setup |

## Git Workflow

```
Agent Run Start
  │
  ├── 1. GitService clones/pulls repo into workspace directory
  │     └── Uses project's SSH private key for auth
  │
  ├── 2. Create feature branch: feature/task-{id} from default_branch
  │
  ├── 3. Mount workspace as volume into Docker container
  │
  ├── 4. Inject SSH key as file mount + set GIT_SSH_COMMAND
  │
  └── 5. Agent works on feature branch inside container
        └── Claude Code handles commits (agent responsibility)
```

### Local Docker Host (MVP)

```
Host Machine
  │
  ├── /var/kodizm/workspaces/{project_id}/
  │   └── repo/              # Cloned/cached repository
  │
  └── Docker Container
      └── /workspace/        # Volume mount of repo
          ├── .git/
          ├── src/
          └── ...
```

### Remote Docker Host (Post-MVP)

```
Kodizm Server                    Remote Docker Host
  │                                   │
  ├── git clone to local cache        │
  ├── SCP workspace → ─────────────── │
  │                                   ├── Mount in container
  │                                   └── Agent works
  │   ←─────────────── SCP back ──── │ (or git push from container)
```

## Key Design Decisions

- **Clone once, pull thereafter** — First run clones the full repo. Subsequent runs do `git fetch + git checkout` for speed.
- **Feature branch per task** — Branch naming: `feature/task-{id}` (configurable). Each task gets its own branch.
- **Agent does the committing** — Kodizm sets up the branch; Claude Code handles `git add`, `git commit` as part of its workflow. Kodizm does NOT commit on behalf of the agent.
- **SSH key mount** — Private key mounted as a read-only file in the container, not passed as env var. `GIT_SSH_COMMAND` configured to use it.
- **No PR creation in MVP** — Agent pushes to the feature branch. PR creation via GitHub API is post-MVP.
- **Workspace caching** — Repos are cached on the host to avoid re-cloning on every run. Cache invalidation: manual or time-based (configurable).
