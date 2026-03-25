# Spec 07 — Real-time Communication

> WebSocket broadcasting via Laravel Reverb for live agent streaming and team notifications.
> Dependencies: 01 (Platform Core — auth, team membership for channel authorization).

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Reverb & Broadcasting | Laravel Reverb installation + config, private channel auth, event classes, broadcasting setup |
| 2 | Event Replay | Stream event replay API for reconnection catch-up, cursor-based pagination, summary mode |

## Dependencies on Other Specs

| Spec | Why |
|------|-----|
| 01 — Platform Core | Sanctum token auth, team membership verification for channel authorization |

Wave 2 also depends on 06-wave-2 (StreamEvent model must exist for replay queries).

## WebSocket Architecture

```
Flutter App
  │
  │  WebSocket (wss://)
  ↓
Laravel Reverb (first-party WebSocket server)
  │
  │  Private channels with Sanctum auth
  ↓
Laravel Broadcasting (event dispatch)
  │
  ├── AgentRunner persists StreamEvent → fires broadcast event
  ├── TaskRun status change → fires broadcast event
  └── Balance deduction → fires broadcast event
```

- Reverb runs as a separate process alongside the Laravel app
- Flutter connects via WebSocket, authenticates with Sanctum token
- All channels are private — require server-side authorization
- Events are fire-and-forget; clients that miss events use the replay API (wave 2)

## Channel Structure

| Channel | Format | Auth Rule | Purpose |
|---------|--------|-----------|---------|
| `private-task-run.{taskRunId}` | Private | User must be team member of task's project | Live agent output streaming, status changes, questions |
| `private-team.{teamId}` | Private | User must be team member | Team-wide notifications: run started/completed, questions, balance changes |

## Key Design Decisions

- **Private channels only** — no public channels. All data is team-scoped.
- **Two channel tiers** — task-run channel for granular streaming, team channel for dashboard-level awareness.
- **No presence channels (MVP)** — no "who's watching" feature. Reduces complexity.
- **Event replay via REST** — WebSocket is ephemeral; reconnection catch-up uses the replay API, not WebSocket backfill.
