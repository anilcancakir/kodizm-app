# Spec 08, Wave 1 — Documents CRUD

> ProjectDocument model, migration, factory, policy, and full CRUD API.
> Dependencies: 02 complete (projects exist).

## Deliverables

1. ProjectDocument model with relationships, casts, and fillable
2. Migration for `project_documents` table
3. Factory for ProjectDocument
4. Policy for ProjectDocument (team role-based authorization)
5. CRUD API endpoints (list, create, show, update, delete)
6. DocumentCategory enum
7. Form request validation classes
8. Tests for model, policy, API endpoints
9. **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## 1. ProjectDocument Schema

```
project_documents
├── id: uuid PK
├── project_id: uuid FK → projects
├── title: string
├── content: text
├── category: enum(architecture, api, guide, convention, runbook, agent_output, other)
├── embedding: vector(1536) nullable  // POST-MVP: pgvector
├── metadata: json nullable
├── created_by_user_id: uuid FK → users nullable
├── created_by_agent_role_id: uuid FK → agent_roles nullable
├── timestamps
└── soft_deletes
```

### Migration Notes

- `project_id`: foreign key to `projects`, cascades on delete
- `category`: use a string column storing the enum value (PHP backed enum handles validation)
- `embedding`: nullable column. For MVP, add as a nullable `text` column (placeholder). When pgvector extension is enabled post-MVP, migrate to `vector(1536)` type.
- `metadata`: nullable JSON column for extensible metadata (e.g., `{ "source_url": "...", "version": "1.2" }`)
- `created_by_user_id`: nullable FK to `users` — set when a human creates the document
- `created_by_agent_role_id`: nullable FK to `agent_roles` — set when an agent creates the document via MCP
- Soft deletes enabled
- Index: `(project_id, category)` for filtered listing queries

### Model Relationships

- `belongsTo` Project
- `belongsTo` User (createdByUser, nullable)
- `belongsTo` AgentRole (createdByAgentRole, nullable)

### Model Casts

- `category` → `DocumentCategory` enum
- `metadata` → `array` (JSON cast)

## 2. DocumentCategory Enum

```php
enum DocumentCategory: string
{
    case Architecture = 'architecture';
    case Api = 'api';
    case Guide = 'guide';
    case Convention = 'convention';
    case Runbook = 'runbook';
    case AgentOutput = 'agent_output';
    case Other = 'other';
}
```

## 3. Policy

Authorization follows the team role permissions from the spec overview:

| Role | List | Create | Update | Delete |
|------|------|--------|--------|--------|
| Owner | Yes | Yes | Yes | Yes |
| Admin | Yes | Yes | Yes | Yes |
| Member | Yes | Yes | Yes | Yes |
| Viewer | Yes (read) | No | No | No |

- All actions require the user to be a member of the team that owns the project
- Viewers can only list and view documents
- Members, Admins, and Owners can create, update, and delete

## 4. API Endpoints

### GET /api/teams/{team}/projects/{project}/documents

List project documents with optional category filter.

**Query Parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `category` | string, nullable | Filter by DocumentCategory value |
| `search` | string, nullable | Search in title (LIKE %query%) |
| `per_page` | integer | Pagination size (default 15, max 100) |

**Response** (200): Paginated list of documents.
```json
{
  "data": [
    {
      "id": 1,
      "title": "API Design Guide",
      "content": "...",
      "category": "api",
      "metadata": null,
      "created_by_user": { "id": 1, "name": "John" },
      "created_by_agent_role": null,
      "created_at": "2026-03-25T10:00:00Z",
      "updated_at": "2026-03-25T10:00:00Z"
    }
  ],
  "meta": { "current_page": 1, "last_page": 3, "per_page": 15, "total": 42 }
}
```

### POST /api/teams/{team}/projects/{project}/documents

Create a new document.

**Request Body**:
```json
{
  "title": "API Design Guide",
  "content": "# API Design\n\nAll endpoints follow REST conventions...",
  "category": "api",
  "metadata": { "version": "1.0" }
}
```

**Validation**:
- `title`: required, string, max 255
- `content`: required, string
- `category`: required, valid DocumentCategory value
- `metadata`: nullable, json/array

**Response** (201): Created document.

### GET /api/teams/{team}/projects/{project}/documents/{document}

Show a single document.

**Response** (200): Full document with relationships.

### PUT /api/teams/{team}/projects/{project}/documents/{document}

Update an existing document.

**Request Body**: Same fields as create (all optional except at least one must be present).

**Validation**:
- `title`: sometimes, string, max 255
- `content`: sometimes, string
- `category`: sometimes, valid DocumentCategory value
- `metadata`: nullable, json/array

**Response** (200): Updated document.

### DELETE /api/teams/{team}/projects/{project}/documents/{document}

Soft-delete a document.

**Response** (204): No content.

## 5. File Structure

```
app/Models/
└── ProjectDocument.php

app/Enums/
└── DocumentCategory.php

app/Policies/
└── ProjectDocumentPolicy.php

app/Http/Controllers/Api/
└── ProjectDocumentController.php

app/Http/Requests/
├── StoreProjectDocumentRequest.php
└── UpdateProjectDocumentRequest.php

app/Http/Resources/
└── ProjectDocumentResource.php

database/migrations/
└── xxxx_xx_xx_create_project_documents_table.php

database/factories/
└── ProjectDocumentFactory.php
```

## Acceptance Criteria

### Model & Migration
- **Given** the migration is run, **when** the `project_documents` table is inspected, **then** it has all columns matching the schema above, including the `(project_id, category)` index.
- **Given** a ProjectDocument instance, **when** `$doc->project` is accessed, **then** it returns the parent Project.
- **Given** a ProjectDocument instance created by a user, **when** `$doc->createdByUser` is accessed, **then** it returns the User.
- **Given** a ProjectDocument with `metadata` set, **when** accessed, **then** it returns a PHP array (JSON cast).

### Factory
- **Given** the factory is used, **when** `ProjectDocument::factory()->create()` is called, **then** a valid document is created with all required fields.
- **Given** the factory, **when** a specific category is passed, **then** the document uses that category.

### Authorization
- **Given** a user with the Viewer role, **when** they attempt to create a document, **then** the response is 403.
- **Given** a user with the Member role, **when** they attempt to create a document, **then** the response is 201.
- **Given** a user who is NOT a member of the team, **when** they attempt any document action, **then** the response is 403.

### List Endpoint
- **Given** a project with 20 documents, **when** `GET /api/teams/{team}/projects/{project}/documents` is called, **then** a paginated list is returned.
- **Given** documents with mixed categories, **when** `?category=api` is passed, **then** only documents with category `api` are returned.
- **Given** documents with various titles, **when** `?search=design` is passed, **then** only documents with "design" in the title are returned.

### Create Endpoint
- **Given** valid input, **when** `POST .../documents` is called, **then** a 201 response with the created document is returned, and `created_by_user_id` is set to the authenticated user.
- **Given** missing `title`, **when** create is called, **then** a 422 validation error is returned.
- **Given** an invalid `category` value, **when** create is called, **then** a 422 validation error is returned.

### Show Endpoint
- **Given** a valid document ID, **when** `GET .../documents/{id}` is called, **then** the full document is returned.
- **Given** a non-existent document ID, **when** show is called, **then** a 404 is returned.
- **Given** a soft-deleted document, **when** show is called, **then** a 404 is returned.

### Update Endpoint
- **Given** a valid document and valid input, **when** `PUT .../documents/{id}` is called, **then** the document is updated and the response is 200.
- **Given** only `content` in the request, **when** update is called, **then** only the content is updated; other fields remain unchanged.

### Delete Endpoint
- **Given** a valid document, **when** `DELETE .../documents/{id}` is called, **then** the document is soft-deleted and the response is 204.
- **Given** a soft-deleted document, **when** delete is called, **then** a 404 is returned.
