# Spec 08, Wave 2 — MCP Server

> MCP HTTP endpoint with JWT authentication and all 11 MCP tools for agent-to-Kodizm communication.
> Dependencies: Wave 1 complete (ProjectDocument model), 06-wave-1 (AgentRunner generates MCP token).

## Deliverables

1. MCP server HTTP endpoint (configurable port, default 4096)
2. JWT token validation middleware
3. All 11 MCP tools with full input/output schemas
4. Role-based access control (tools 7-8 restricted to BA and Lead Dev)
5. MCP token generation logic (called by AgentRunner before container start)
6. Tests for JWT middleware, all 11 tools, role-based access
7. **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## 1. MCP Server Architecture

### HTTP Endpoint

The MCP server is an HTTP endpoint served by the Laravel application. It follows the MCP (Model Context Protocol) specification for tool invocation over HTTP.

- **Port**: Configurable via `config('mcp.port')`, default 4096
- **Base URL**: `http://{host}:{port}/mcp`
- **Transport**: HTTP/JSON (not stdio)
- **Content-Type**: `application/json`

### Request Flow

```
Docker Container
  │
  │  POST http://KODIZM_MCP_ENDPOINT/mcp/tools/{tool_name}
  │  Authorization: Bearer {KODIZM_MCP_TOKEN}
  │  Content-Type: application/json
  │  Body: { ...tool input... }
  ↓
MCP Middleware (JWT validation)
  │
  │  Verify JWT signature → extract claims:
  │  { task_run_id, project_id, team_id, agent_role_slug, exp }
  ↓
MCP Tool Handler
  │
  │  All queries scoped to project_id from JWT
  │  Role checks against agent_role_slug
  ↓
Response: { ...tool output... }
```

### Container Environment

The container receives two env vars for MCP communication:

| Env Var | Value | Example |
|---------|-------|---------|
| `KODIZM_MCP_ENDPOINT` | Base URL of MCP server | `http://host.docker.internal:4096` |
| `KODIZM_MCP_TOKEN` | Signed JWT for this run | `eyJhbGciOiJIUzI1NiJ9...` |

## 2. JWT Token Validation

### Token Structure

```json
{
  "task_run_id": 123,
  "project_id": 45,
  "team_id": 1,
  "agent_role_slug": "developer",
  "exp": 1711411200
}
```

### Token Generation

Called by AgentRunner before container start:

1. Build JWT payload with `task_run_id`, `project_id`, `team_id`, `agent_role_slug`
2. Set expiration: `now() + 24 hours`
3. Sign with `config('mcp.jwt_secret')` (application-level secret, NOT per-user)
4. Store token on `task_runs.mcp_token` (backup/lookup fallback)
5. Inject as `KODIZM_MCP_TOKEN` env var into container

### Middleware Behavior

1. Extract `Authorization: Bearer {token}` header
2. Verify JWT signature using `config('mcp.jwt_secret')`
3. Check expiration (`exp` claim)
4. Extract claims: `task_run_id`, `project_id`, `team_id`, `agent_role_slug`
5. Verify TaskRun exists and is in `running` or `waiting_for_input` status
6. Bind claims to request context (available in tool handlers)
7. On failure: return 401 with error message

### Error Responses

| Scenario | HTTP Status | Error |
|----------|-------------|-------|
| Missing Authorization header | 401 | `missing_token` |
| Invalid JWT signature | 401 | `invalid_token` |
| Expired JWT | 401 | `token_expired` |
| TaskRun not found or terminal status | 401 | `invalid_run` |

## 3. MCP Tools

All 11 tools with full input/output schemas. Every tool's database queries are scoped to `project_id` from the JWT claims.

---

### Tool 1: report-progress

Report agent status and progress to Kodizm.

**Access**: All agents

**Input**:
```json
{
  "status": "string",
  "message": "string",
  "percentage": "number|null"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `status` | string | yes | Free-text status label (e.g., "analyzing", "implementing", "testing") |
| `message` | string | yes | Human-readable progress message |
| `percentage` | number, nullable | no | Progress percentage (0-100) |

**Output**:
```json
{
  "ok": true
}
```

**Behavior**:
- Update `task_runs` record with latest progress info (stored in a JSON field or broadcast only)
- Broadcast progress event on task-run channel (if wave 07-1 is complete)
- No persistence required for MVP — fire-and-forget broadcast is sufficient

---

### Tool 2: get-task

Read current task details.

**Access**: All agents

**Input**:
```json
{}
```

No input required. Task is resolved from `task_run_id` in JWT → `task_runs.task_id`.

**Output**:
```json
{
  "id": 45,
  "title": "Implement user authentication",
  "description": "Add login and registration endpoints...",
  "acceptance_criteria": "Given a valid email and password, when POST /auth/login...",
  "type": "story",
  "priority": "p1",
  "status": "in_progress",
  "sections": [
    {
      "type": "analysis",
      "title": "Requirements Analysis",
      "content": "The authentication system needs..."
    },
    {
      "type": "plan",
      "title": "Implementation Plan",
      "content": "1. Create User model..."
    }
  ]
}
```

**Behavior**:
- Resolve TaskRun from JWT → load Task with sections
- Return task fields + all TaskSections ordered by `created_at`

---

### Tool 3: get-project-info

Read project metadata and tech stack.

**Access**: All agents

**Input**:
```json
{}
```

No input required. Project is resolved from `project_id` in JWT.

**Output**:
```json
{
  "id": 12,
  "name": "Kodizm Backend",
  "tech_stack": "laravel-flutter",
  "default_branch": "main",
  "repository_url": "git@github.com:kodizm/backend.git"
}
```

**Behavior**:
- Load Project by `project_id` from JWT
- Return only the fields relevant to agent work (no sensitive data like SSH keys)

---

### Tool 4: create-task-section

Write a new section (analysis, plan, report, etc.) to the current task.

**Access**: All agents

**Input**:
```json
{
  "type": "TaskSectionType",
  "title": "string|null",
  "content": "string"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | TaskSectionType enum | yes | Section type: analysis, plan, design_brief, design_assets, dev_report, review_report, test_report, notes, comments |
| `title` | string, nullable | no | Section title (auto-generated from type if null) |
| `content` | string | yes | Section content (markdown) |

**Output**:
```json
{
  "id": 78,
  "type": "analysis",
  "version": 1
}
```

**Behavior**:
- Create TaskSection on the task from JWT context
- Set `created_by_agent_role_id` from JWT's agent role
- Version starts at 1

---

### Tool 5: update-task-section

Update an existing task section. Version auto-increments.

**Access**: All agents

**Input**:
```json
{
  "section_id": 78,
  "content": "string"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `section_id` | number | yes | ID of the section to update |
| `content` | string | yes | New content (replaces existing) |

**Output**:
```json
{
  "id": 78,
  "version": 2
}
```

**Behavior**:
- Verify section belongs to the task from JWT context
- Update content, increment `version` by 1
- Return updated section ID and new version

---

### Tool 6: search-knowledge

Search project and team knowledge base documents.

**Access**: All agents

**Input**:
```json
{
  "query": "authentication flow",
  "limit": 5
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `query` | string | yes | Search query |
| `limit` | number, nullable | no | Max results (default 5) |

**Output**:
```json
{
  "results": [
    {
      "id": 10,
      "title": "Auth Architecture",
      "content": "The authentication system uses...",
      "category": "architecture",
      "relevance_score": 0.85
    }
  ]
}
```

**Behavior**:
- MVP: keyword search using SQL LIKE on `title` and `content` fields, scoped to `project_id` from JWT
- Relevance score in MVP: simple ranking based on match position/frequency (0.0-1.0)
- POST-MVP: pgvector semantic search using embeddings
- Results ordered by relevance score descending

---

### Tool 7: create-task

Create a new task or sub-task.

**Access**: BA and Lead Dev agent roles only

**Input**:
```json
{
  "title": "Add email validation",
  "description": "Implement server-side email format validation...",
  "type": "task",
  "priority": "p2",
  "acceptance_criteria": "Given an invalid email format, when submitted...",
  "parent_task_id": 45,
  "design_needed": false
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | yes | Task title |
| `description` | string, nullable | no | Task description |
| `type` | TaskType enum | yes | story, task, bug, spike |
| `priority` | TaskPriority enum, nullable | no | p0, p1, p2, p3 (default p2) |
| `acceptance_criteria` | string, nullable | no | Acceptance criteria text |
| `parent_task_id` | number, nullable | no | Parent task ID for sub-tasks |
| `design_needed` | boolean, nullable | no | Whether design stage is needed |

**Output**:
```json
{
  "id": 67,
  "title": "Add email validation",
  "status": "draft"
}
```

**Behavior**:
- Create task in the project from JWT context
- Set `created_by_user_id` to null (agent-created)
- Set status to `draft`
- Set `source` to `manual` (agent-created tasks use manual source)
- If `parent_task_id` provided, verify parent task belongs to the same project
- Return 403 if agent role is not BA or Lead Dev

---

### Tool 8: update-task

Update an existing task's fields.

**Access**: BA and Lead Dev agent roles only

**Input**:
```json
{
  "task_id": 45,
  "title": "Updated title",
  "description": "Updated description...",
  "status": "planning",
  "priority": "p1",
  "acceptance_criteria": "Updated AC..."
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `task_id` | number | yes | ID of the task to update |
| `title` | string, nullable | no | New title |
| `description` | string, nullable | no | New description |
| `status` | TaskStatus enum, nullable | no | New status (must follow valid transitions) |
| `priority` | TaskPriority enum, nullable | no | New priority |
| `acceptance_criteria` | string, nullable | no | New acceptance criteria |

**Output**:
```json
{
  "id": 45,
  "title": "Updated title",
  "status": "planning"
}
```

**Behavior**:
- Verify task belongs to the project from JWT context
- If status change requested, validate against allowed transitions
- Return 403 if agent role is not BA or Lead Dev
- Return 422 if status transition is invalid

---

### Tool 9: create-document

Create a new project document.

**Access**: All agents

**Input**:
```json
{
  "title": "API Endpoint Reference",
  "content": "# API Reference\n\n## Auth Endpoints\n...",
  "category": "api"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | yes | Document title |
| `content` | string | yes | Document content (markdown) |
| `category` | DocumentCategory enum | yes | architecture, api, guide, convention, runbook, agent_output, other |

**Output**:
```json
{
  "id": 15,
  "title": "API Endpoint Reference"
}
```

**Behavior**:
- Create ProjectDocument in the project from JWT context
- Set `created_by_agent_role_id` from JWT's agent role
- Set `created_by_user_id` to null (agent-created)
- `embedding` left null (POST-MVP)

---

### Tool 10: update-document

Update an existing project document.

**Access**: All agents

**Input**:
```json
{
  "document_id": 15,
  "content": "# Updated API Reference\n...",
  "title": "Updated API Endpoint Reference"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `document_id` | number | yes | ID of the document to update |
| `content` | string | yes | New content |
| `title` | string, nullable | no | New title (optional) |

**Output**:
```json
{
  "id": 15,
  "title": "Updated API Endpoint Reference"
}
```

**Behavior**:
- Verify document belongs to the project from JWT context
- Update content and optionally title
- Return 404 if document not found in project scope

---

### Tool 11: search-documents

Search project documents by query and optional category filter.

**Access**: All agents

**Input**:
```json
{
  "query": "authentication",
  "category": "architecture",
  "limit": 10
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `query` | string | yes | Search query |
| `category` | DocumentCategory enum, nullable | no | Filter by category |
| `limit` | number, nullable | no | Max results (default 10) |

**Output**:
```json
{
  "results": [
    {
      "id": 10,
      "title": "Auth Architecture",
      "content": "The authentication system uses...",
      "category": "architecture"
    }
  ]
}
```

**Behavior**:
- Search ProjectDocuments scoped to `project_id` from JWT
- MVP: SQL LIKE search on `title` and `content`
- If `category` provided, filter by category
- Limit results (default 10)

## 4. Role-Based Access Control

| Tool | All Agents | BA Only | Lead Dev Only |
|------|-----------|---------|---------------|
| report-progress | Yes | | |
| get-task | Yes | | |
| get-project-info | Yes | | |
| create-task-section | Yes | | |
| update-task-section | Yes | | |
| search-knowledge | Yes | | |
| create-task | | Yes | Yes |
| update-task | | Yes | Yes |
| create-document | Yes | | |
| update-document | Yes | | |
| search-documents | Yes | | |

**Implementation**: Check `agent_role_slug` from JWT claims. If tool requires BA/Lead Dev access and the slug is not `ba` or `lead-dev`, return 403.

## 5. MCP Token Generation

Called by AgentRunner before container start (lives in AgentRunner service, spec 06):

```
1. Build payload: { task_run_id, project_id, team_id, agent_role_slug, exp: now + 24h }
2. Sign JWT with config('mcp.jwt_secret') using HS256
3. Store on task_runs.mcp_token
4. Return token string
```

### Configuration

```php
// config/mcp.php
'port' => env('MCP_PORT', 4096),
'jwt_secret' => env('MCP_JWT_SECRET'),  // Required, no default
'jwt_algorithm' => 'HS256',
'token_ttl_hours' => 24,
```

## 6. File Structure

```
app/Http/Controllers/Mcp/
├── McpController.php               # Routes tool calls to handlers
└── Tools/
    ├── ReportProgressTool.php
    ├── GetTaskTool.php
    ├── GetProjectInfoTool.php
    ├── CreateTaskSectionTool.php
    ├── UpdateTaskSectionTool.php
    ├── SearchKnowledgeTool.php
    ├── CreateTaskTool.php
    ├── UpdateTaskTool.php
    ├── CreateDocumentTool.php
    ├── UpdateDocumentTool.php
    └── SearchDocumentsTool.php

app/Http/Middleware/
└── ValidateMcpToken.php            # JWT validation middleware

app/Services/
└── McpTokenService.php             # Token generation + validation

config/
└── mcp.php                         # MCP server config

routes/
└── mcp.php                         # MCP tool routes
```

## Acceptance Criteria

### JWT Middleware
- **Given** a valid JWT with correct signature and non-expired claims, **when** a tool endpoint is called, **then** the request proceeds and claims are available in the handler.
- **Given** a missing Authorization header, **when** a tool endpoint is called, **then** 401 is returned with `missing_token` error.
- **Given** an invalid JWT signature, **when** a tool endpoint is called, **then** 401 is returned with `invalid_token` error.
- **Given** an expired JWT, **when** a tool endpoint is called, **then** 401 is returned with `token_expired` error.
- **Given** a JWT for a TaskRun that is in `completed` status, **when** a tool endpoint is called, **then** 401 is returned with `invalid_run` error.

### Token Generation
- **Given** a TaskRun is being started by AgentRunner, **when** the MCP token is generated, **then** it contains `task_run_id`, `project_id`, `team_id`, `agent_role_slug`, and `exp` (24h from now).
- **Given** a generated token, **when** stored on `task_runs.mcp_token`, **then** it can be verified by the middleware.

### Tool: report-progress
- **Given** a valid MCP token and valid input, **when** `report-progress` is called, **then** `{ "ok": true }` is returned.
- **Given** missing `status` field, **when** called, **then** 422 validation error is returned.

### Tool: get-task
- **Given** a valid MCP token, **when** `get-task` is called, **then** the task associated with the TaskRun is returned with all sections.
- **Given** a task with 3 sections, **when** `get-task` is called, **then** all 3 sections are included in the response.

### Tool: get-project-info
- **Given** a valid MCP token, **when** `get-project-info` is called, **then** the project info is returned without sensitive fields (no SSH keys).

### Tool: create-task-section
- **Given** valid input with type `analysis` and content, **when** `create-task-section` is called, **then** a new TaskSection is created with version 1, linked to the task from JWT context.
- **Given** an invalid section type, **when** called, **then** 422 is returned.

### Tool: update-task-section
- **Given** a valid section ID belonging to the task, **when** `update-task-section` is called with new content, **then** the section's content is updated and version is incremented.
- **Given** a section ID that does NOT belong to the task, **when** called, **then** 404 is returned.

### Tool: search-knowledge
- **Given** documents exist with keyword "auth" in title, **when** `search-knowledge` is called with query "auth", **then** matching documents are returned with relevance scores.
- **Given** `limit=3`, **when** called, **then** at most 3 results are returned.

### Tool: create-task (Role-restricted)
- **Given** a JWT with `agent_role_slug = "ba"`, **when** `create-task` is called with valid input, **then** a new task is created in `draft` status.
- **Given** a JWT with `agent_role_slug = "lead-dev"`, **when** `create-task` is called, **then** the task is created successfully.
- **Given** a JWT with `agent_role_slug = "developer"`, **when** `create-task` is called, **then** 403 is returned.
- **Given** a `parent_task_id` that does NOT belong to the project, **when** called, **then** 422 is returned.

### Tool: update-task (Role-restricted)
- **Given** a JWT with `agent_role_slug = "ba"` and a valid task ID, **when** `update-task` is called, **then** the task is updated.
- **Given** a JWT with `agent_role_slug = "qa"`, **when** `update-task` is called, **then** 403 is returned.
- **Given** a status transition that violates the state machine, **when** called, **then** 422 is returned with details of allowed transitions.

### Tool: create-document
- **Given** valid input, **when** `create-document` is called, **then** a ProjectDocument is created with `created_by_agent_role_id` set from JWT.
- **Given** an invalid category, **when** called, **then** 422 is returned.

### Tool: update-document
- **Given** a valid document ID in the project, **when** `update-document` is called, **then** the document is updated.
- **Given** a document ID from a different project, **when** called, **then** 404 is returned.

### Tool: search-documents
- **Given** documents in the project, **when** `search-documents` is called with a query, **then** matching documents are returned.
- **Given** `category = "api"`, **when** called, **then** only documents with category `api` are returned.

### Project Scoping
- **Given** a JWT scoped to project A, **when** any tool attempts to access data from project B, **then** the data is not returned (404 or empty results).
