# Wave 6 — Billing, Settings & Polish

> Spec: 11-Flutter App
> Dependencies: Wave 5 complete, 09-Billing & Credits complete (balance/usage APIs)

## Deliverables

- [ ] Team billing/credits view
- [ ] Usage history screen (with filtering)
- [ ] App settings screen
- [ ] AI Tokens overview screen (read-only)
- [ ] Responsive polish (verify Kodizm-specific screens work on web + mobile layouts)
- [ ] BillingState (ChangeNotifier + MagicStateMixin)
- [ ] Freezed models: UsageRecord with UUID `String` ids

**TDD**: All code developed test-first (red-green-refactor). Widget tests for screens, unit tests for state/services.

## Team Billing/Credits View (`/billing`)

### Layout

```
+--------------------------------------------------------------+
|  Billing -- Team Name                                         |
+--------------------------------------------------------------+
|                                                               |
|  Current Balance                                              |
|  +----------------------------------------------------------+|
|  |                    $42.50                                  ||
|  |              [Add Credits ->]                              ||
|  +----------------------------------------------------------+|
|                                                               |
|  Monthly Summary                                              |
|  +----------------------------------------------------------+|
|  |  March 2026                                               ||
|  |  Total Spent: $123.45                                     ||
|  |  Runs: 89                                                 ||
|  |  Avg Cost/Run: $1.39                                      ||
|  +----------------------------------------------------------+|
|                                                               |
|  Usage by Agent Role                                          |
|  +----------------------------------------------------------+|
|  |  Developer     $67.20  (54%)  [===========          ]     ||
|  |  QA            $32.10  (26%)  [=====                ]     ||
|  |  Code Reviewer  $18.90  (15%)  [===                 ]     ||
|  |  BA             $5.25   (4%)  [=                    ]     ||
|  +----------------------------------------------------------+|
|                                                               |
|  [View Full Usage History ->]                                 |
+--------------------------------------------------------------+
```

### Data Source
- Balance: from GET `/api/teams/{team}/balance` via `Http`
- Monthly summary: from GET `/api/teams/{team}/usage?period=2026-03` via `Http`
- Usage by agent role: aggregated from usage data

### Balance Display
- Large centered number with currency formatting
- Color coding: green (> $10), yellow ($1-$10), red (< $1)
- "Add Credits" link (placeholder in MVP — links to admin panel or payment flow)

## Usage History Screen (`/usage`)

### Layout
- List of usage records, sorted by most recent
- Each record shows:
  - Date/time
  - Agent role
  - Task title (linked)
  - Model used
  - Input/output tokens
  - Cost (`$X.XX`)
- **Filters**:
  - Period: month picker (default: current month)
  - Project: dropdown (all projects in team)
  - Agent role: multi-select chips
- **Summary**: total cost for filtered period at top
- Pull-to-refresh
- Pagination for large datasets

### Data Source
- GET `/api/teams/{team}/usage` via `Http`
- Query params: `period`, `project_id`, `agent_role`

## AI Tokens Overview (part of team settings or `/settings/ai-tokens`)

### Display
- List of team's AI tokens (from GET `/api/teams/{team}/ai-tokens` via `Http`)
- Each token card:
  - **Provider badge**: Anthropic (orange), OpenAI (green), Google (blue), OpenRouter (purple)
  - **Label**: e.g., "Claude Max Account #1"
  - **Auth type**: API Key / Subscription
  - **Status indicator**:
    - Active -> green dot
    - Inactive -> grey dot
    - Rate limited -> yellow dot with cooldown timer
    - Expired -> red dot
  - **Credentials**: masked display (e.g., `sk-...abc123`)
  - **Usage count**: total uses
  - **Last used**: relative time

### Actions
- View only in Flutter app (CRUD is in Filament admin panel)
- Tap token -> shows detail modal with full info
- No edit/delete from Flutter (admin panel only)

## App Settings Screen (`/settings`)

### Sections

#### Appearance
- Theme mode: Light / Dark / System (default: Dark)
- Persisted in Vault

#### Notifications
- Enable/disable push notifications (mobile)
- Notification types: run completed, run failed, question pending, balance low

#### About
- App version
- Build number
- API server URL (read-only, from env)
- "Terms of Service" and "Privacy Policy" links

## Responsive Polish

magic_starter provides the responsive layout (sidebar on desktop, drawer + bottom nav on mobile). This wave verifies that all Kodizm-specific screens work correctly in both modes:

### Verification Checklist
- [ ] ProjectListScreen: cards reflow on narrow screens
- [ ] ProjectDetailScreen: tabs stack vertically on mobile
- [ ] TaskListScreen: filter chips wrap on narrow screens
- [ ] TaskDetailScreen: sections tab scrolls properly on mobile
- [ ] AgentRunScreen: terminal full-width on mobile, sidebar collapsible
- [ ] DashboardScreen: stat cards stack on mobile, charts resize
- [ ] BillingScreen: usage bars resize proportionally
- [ ] KnowledgeListScreen: cards reflow on narrow screens
- [ ] Navigation: sidebar visible on desktop (>=1024px), drawer on tablet/mobile (<1024px)
- [ ] Bottom nav: visible on mobile, hidden on desktop

### Breakpoints (from magic)
- Mobile: < 768px
- Tablet: 768px - 1023px
- Desktop: >= 1024px

## State Management

### BillingState (ChangeNotifier + MagicStateMixin)

```dart
class BillingState extends ChangeNotifier with MagicStateMixin {
  double _balance = 0.0;
  List<UsageRecord> _usageRecords = [];
  MonthlyUsage? _monthlySummary;

  double get balance => _balance;
  List<UsageRecord> get usageRecords => _usageRecords;
  MonthlyUsage? get monthlySummary => _monthlySummary;

  Future<void> loadBalance(String teamId) async {
    await run(() async {
      final response = await Http.get('/teams/$teamId/balance');
      _balance = (response.data['data']['balance'] as num).toDouble();
      notifyListeners();
    });
  }

  Future<void> loadUsage(
    String teamId, {
    String? period,
    String? projectId,
    String? agentRole,
  }) async {
    await run(() async {
      final queryParams = <String, dynamic>{};
      if (period != null) queryParams['period'] = period;
      if (projectId != null) queryParams['project_id'] = projectId;
      if (agentRole != null) queryParams['agent_role'] = agentRole;

      final response = await Http.get(
        '/teams/$teamId/usage',
        queryParameters: queryParams,
      );
      _usageRecords = (response.data['data'] as List)
          .map((json) => UsageRecord.fromJson(json))
          .toList();
      notifyListeners();
    });
  }

  Future<void> loadMonthlySummary(String teamId, String period) async {
    await run(() async {
      final response = await Http.get('/teams/$teamId/usage', queryParameters: {'period': period});
      // Aggregate from response
      final records = (response.data['data'] as List).map((json) => UsageRecord.fromJson(json)).toList();
      final totalCost = records.fold<double>(0.0, (sum, r) => sum + r.costUsd);
      _monthlySummary = MonthlyUsage(
        totalCostUsd: totalCost,
        period: period,
        runCount: records.length,
      );
      notifyListeners();
    });
  }
}
```

## Freezed Models

### UsageRecord

```dart
@freezed
class UsageRecord with _$UsageRecord {
  const factory UsageRecord({
    required String id,              // UUID
    required String teamId,          // UUID
    String? taskRunId,               // UUID
    String? model,
    int? inputTokens,
    int? outputTokens,
    required double costUsd,
    required String period,
    required DateTime recordedAt,
    // included in response
    String? agentRoleName,
    String? taskTitle,
    String? projectName,
  }) = _UsageRecord;

  factory UsageRecord.fromJson(Map<String, dynamic> json) => _$UsageRecordFromJson(json);
}
```

## Acceptance Criteria

### Billing/Credits

**Given** a team with balance $42.50,
**When** the user navigates to the billing screen,
**Then** the balance is displayed as `$42.50` with green color (> $10).

**Given** a team with balance $0.50,
**When** the user views the balance,
**Then** it shows `$0.50` in red (< $1).

**Given** a team with usage data for March 2026,
**When** the user views the billing screen,
**Then** the monthly summary shows total spent, run count, and average cost per run.

### Usage History

**Given** a team with 50 usage records,
**When** the user navigates to the usage history screen,
**Then** records are listed with date, agent role, task title, model, tokens, and cost.

**Given** the usage history screen with a period filter set to "2026-02",
**When** the filter is applied,
**Then** only usage records from February 2026 are displayed.

**Given** the usage history screen with a project filter,
**When** a specific project is selected,
**Then** only usage records for that project are displayed.

### AI Tokens

**Given** a team with 3 AI tokens (1 active, 1 rate_limited, 1 inactive),
**When** the user views the AI tokens screen,
**Then** all 3 tokens are listed with correct status indicators (green dot, yellow dot, grey dot).

**Given** an AI token with masked credentials,
**When** the user views the token card,
**Then** the API key is displayed as `sk-...abc123` (first 3 + last 6 characters visible).

### App Settings

**Given** a user on the app settings screen,
**When** they toggle the theme from Dark to Light,
**Then** the app theme changes immediately and the preference is persisted in Vault.

**Given** a user on the app settings screen,
**When** they view the About section,
**Then** the app version, build number, and API server URL are displayed.

### Responsive Polish

**Given** the Kodizm app running on a desktop browser (>= 1024px),
**When** the user views any screen,
**Then** the sidebar navigation is visible and content fills the main area.

**Given** the Kodizm app running on a mobile device (< 768px),
**When** the user views any screen,
**Then** the drawer navigation is accessible via hamburger menu and bottom nav is visible.

**Given** the AgentRunScreen on a mobile device,
**When** the user views it,
**Then** the terminal is full-width, run info is in a collapsible top bar, and file changes are accessible via bottom sheet.

**Given** the DashboardScreen on a mobile device,
**When** the user views it,
**Then** stat cards stack vertically and the layout is scrollable.

## Implementation Notes

- Use `Http` facade for ALL API calls — never instantiate Dio directly.
- All model IDs are `String` (UUID) — no `int` IDs.
- State classes: `extends ChangeNotifier with MagicStateMixin`.
- AI tokens are read-only in Flutter — direct users to the Filament admin panel for management.
- Monthly usage period defaults to current month. Consider adding a month picker for historical view.
- Balance color coding thresholds should be configurable constants.
- Responsive polish is mostly verification — magic_starter handles the layout. Focus on ensuring Kodizm-specific screens adapt correctly.
- Theme mode persistence: use Vault to store the preference, apply via `ThemeMode` in MaterialApp.
- Usage history should paginate for performance on large datasets.
