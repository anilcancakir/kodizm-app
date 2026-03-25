# Spec 02 — Project Management

> Project CRUD, settings, SSH key generation, git connection.
> Dependencies: Spec 01 (Platform Core) must be complete.

## Waves

| Wave | Name | Deliverables |
|------|------|-------------|
| 1 | Project CRUD | Project model + migration + factory + policy, CRUD endpoints, settings |
| 2 | SSH & Git Connection | SSH keypair generation, public key display, git clone trigger, repo status |

## Dependencies on Other Specs

- **Spec 01 — Platform Core**: Team model (projects belong to teams), auth (all endpoints require auth), TeamRole permissions (who can create/edit projects). **Note**: User and Team models come from magic-starter and are extended by Kodizm.

## Data Models

### Project
```
projects
├── id: uuid PK
├── team_id: uuid FK → teams
├── name: string
├── slug: string
├── description: text nullable
├── repository_url: string nullable       // git@github.com:org/repo.git
├── default_branch: string default 'main'
├── tech_stack: string nullable            // e.g. 'laravel-flutter', 'laravel-blade'
├── ssh_private_key: text encrypted nullable  // for private repo access
├── ssh_public_key: text nullable             // displayed to user for deploy key setup
├── execution_mode: enum(manual, semi_auto, full_auto) default 'manual'
├── pipeline_config: json nullable         // pipeline stage→agent mapping (POST-MVP)
├── settings: json nullable                // project-specific settings
├── timestamps
└── soft_deletes
```

**Notes on POST-MVP fields** (include in migration, don't expose in MVP API):
- `execution_mode`: Always `manual` in MVP. Semi-auto and full-auto are post-MVP.
- `pipeline_config`: Not used in MVP. Store the column for future use.

**Note on sprint_id**: The `sprint_id` field on tasks references a `sprints` table that is POST-MVP. Do NOT create a sprints table or migration in this spec.

## Relevant Enums

```php
enum ExecutionMode: string
{
    case Manual = 'manual';
    case SemiAuto = 'semi_auto';
    case FullAuto = 'full_auto';
}
```

## Business Rules

- Projects are scoped to a team via `team_id` FK.
- Project slug is unique within a team (not globally).
- Slug is auto-generated from name, unique within team scope.
- Owner, Admin, and Member roles can create projects.
- Viewer role has read-only access.
- SSH private key is encrypted at rest using Laravel's `encrypted` cast.
- SSH public key is stored in plaintext (it's meant to be shared).
- Soft deletes on Project model.
