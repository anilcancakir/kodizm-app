# Wave 2 — SSH & Git Connection

> Spec: 02-Project Management
> Dependencies: Wave 1 (Project CRUD) must be complete

## Deliverables

- [ ] SshKeyService (generates Ed25519 keypair, stores encrypted)
- [ ] Generate SSH key endpoint
- [ ] Get SSH public key endpoint
- [ ] Clone repo trigger endpoint
- [ ] Repo status check endpoint
- [ ] Feature tests for all endpoints
- [ ] **TDD**: All code developed test-first (red-green-refactor). Feature tests for API endpoints, unit tests for services and models.

## SSH Key Generation

### SshKeyService

Service responsible for generating and managing SSH keypairs for project git access.

**Methods**:
```php
class SshKeyService
{
    /**
     * Generate a new Ed25519 SSH keypair for a project.
     * Stores private key encrypted, public key plaintext.
     * Returns the public key string.
     */
    public function generate(Project $project): string;

    /**
     * Check if a project has an SSH keypair configured.
     */
    public function hasKey(Project $project): bool;
}
```

**Key generation details**:
- Algorithm: Ed25519 (preferred for security and performance)
- Use PHP's `sodium_crypto_sign_keypair()` or shell out to `ssh-keygen -t ed25519 -C "kodizm-project-{id}" -N "" -f /tmp/key` and read the files.
- Private key: stored in `projects.ssh_private_key` (encrypted at rest via Laravel cast)
- Public key: stored in `projects.ssh_public_key` (plaintext — user copies this to GitHub/GitLab as deploy key)
- Comment on public key: `kodizm-project-{id}`
- Generating a new keypair replaces the existing one (no key history).

## API Endpoints

### POST /api/teams/{team}/projects/{project}/generate-ssh-key

Generate a new SSH keypair for the project. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Request**: Empty body.

**Response** `200 OK`:
```json
{
    "data": {
        "ssh_public_key": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPx... kodizm-project-1",
        "message": "SSH keypair generated. Add the public key as a deploy key in your git provider."
    }
}
```

**Notes**:
- Overwrites any existing keypair.
- Only the public key is returned. Private key is never exposed via API.

**Errors**:
- `403` — Not owner or admin

---

### GET /api/teams/{team}/projects/{project}/ssh-public-key

Get the project's SSH public key (for deploy key setup). Requires team membership.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK`:
```json
{
    "data": {
        "ssh_public_key": "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHPx... kodizm-project-1",
        "has_key": true
    }
}
```

**Response when no key exists** `200 OK`:
```json
{
    "data": {
        "ssh_public_key": null,
        "has_key": false
    }
}
```

---

### POST /api/teams/{team}/projects/{project}/clone-repo

Trigger a git clone of the project's repository. Requires owner or admin role.

**Headers**: `Authorization: Bearer {token}`

**Request**: Empty body.

**Response** `202 Accepted`:
```json
{
    "data": {
        "status": "cloning",
        "message": "Repository clone initiated."
    }
}
```

**Preconditions** (return 422 if not met):
- `repository_url` must be set on the project
- `ssh_private_key` must be set (keypair generated)

**Errors**:
- `403` — Not owner or admin
- `422` — Missing repository_url or SSH key

**Notes**:
- This dispatches a background job to clone the repo. The actual clone happens asynchronously.
- MVP: Clone to a local cache directory on the Laravel server. Path: `storage/repos/{team_id}/{project_id}/`.
- The job uses the project's SSH private key for authentication.
- On success, repo status is updated. On failure, error is stored.

---

### GET /api/teams/{team}/projects/{project}/repo-status

Check the git repository status. Requires team membership.

**Headers**: `Authorization: Bearer {token}`

**Response** `200 OK` (repo cloned):
```json
{
    "data": {
        "status": "cloned",
        "default_branch": "main",
        "last_synced_at": "2026-03-25T10:30:00Z",
        "error": null
    }
}
```

**Response** `200 OK` (not cloned):
```json
{
    "data": {
        "status": "not_cloned",
        "default_branch": "main",
        "last_synced_at": null,
        "error": null
    }
}
```

**Response** `200 OK` (clone failed):
```json
{
    "data": {
        "status": "error",
        "default_branch": "main",
        "last_synced_at": null,
        "error": "Permission denied (publickey). Make sure the deploy key is added to your repository."
    }
}
```

**Possible statuses**: `not_cloned`, `cloning`, `cloned`, `error`

## Acceptance Criteria

### SSH Key Generation

**Given** a project without an SSH key,
**When** an admin POSTs to `/api/teams/{team}/projects/{project}/generate-ssh-key`,
**Then** an Ed25519 keypair is generated, private key is stored encrypted, public key is stored plaintext, and the public key is returned.

**Given** a project with an existing SSH key,
**When** an admin POSTs to `/api/teams/{team}/projects/{project}/generate-ssh-key`,
**Then** the old keypair is replaced with a new one.

**Given** a team member with `member` role,
**When** they POST to `/api/teams/{team}/projects/{project}/generate-ssh-key`,
**Then** a 403 response is returned.

### SSH Public Key Display

**Given** a project with a generated SSH key,
**When** any team member GETs `/api/teams/{team}/projects/{project}/ssh-public-key`,
**Then** the public key string is returned with `has_key: true`.

**Given** a project without an SSH key,
**When** any team member GETs the ssh-public-key endpoint,
**Then** `ssh_public_key: null` and `has_key: false` is returned.

### Clone Repo

**Given** a project with `repository_url` and SSH key configured,
**When** an admin POSTs to `/api/teams/{team}/projects/{project}/clone-repo`,
**Then** a background job is dispatched and a 202 response is returned.

**Given** a project without `repository_url`,
**When** an admin POSTs to clone-repo,
**Then** a 422 response is returned with a message about missing repository URL.

**Given** a project without an SSH key,
**When** an admin POSTs to clone-repo,
**Then** a 422 response is returned with a message about missing SSH key.

### Repo Status

**Given** a project that has been successfully cloned,
**When** a team member GETs `/api/teams/{team}/projects/{project}/repo-status`,
**Then** `status: "cloned"` is returned with `last_synced_at` timestamp.

**Given** a project that has never been cloned,
**When** a team member GETs repo-status,
**Then** `status: "not_cloned"` is returned.

**Given** a project where clone failed,
**When** a team member GETs repo-status,
**Then** `status: "error"` is returned with the error message.

## Implementation Notes

- SSH key generation: prefer `sodium_crypto_sign_keypair()` for pure PHP. If Ed25519 SSH format is complex to produce from sodium, shell out to `ssh-keygen` in a temporary directory and read the files.
- Repo clone job: `CloneRepositoryJob` dispatched to a queue. Writes SSH key to a temp file, runs `git clone` with `GIT_SSH_COMMAND="ssh -i /tmp/key -o StrictHostKeyChecking=no"`.
- Repo status tracking: store in `projects.settings` JSON under a `repo_status` key, or use Redis cache. Keep it simple for MVP.
- The clone-repo endpoint is about cloning to the server's local cache. The actual container-level clone happens during agent execution (Spec 06/10).
