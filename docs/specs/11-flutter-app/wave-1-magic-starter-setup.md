# Wave 1 — Magic Starter Integration & Core Setup

> Spec: 11-Flutter App
> Dependencies: 01-Platform Core complete (backend auth + team endpoints available)

## Deliverables

- [ ] Flutter project initialization using `magic_starter` scaffold
- [ ] Configure magic_starter feature flags for Kodizm (enable/disable features)
- [ ] Configure Kodizm theme and branding (colors, typography, logo)
- [ ] Register Kodizm-specific Go Router routes alongside magic's default routes
- [ ] WebSocket service (singleton, auto-reconnect) for Reverb integration
- [ ] Verify auth flow works end-to-end (login -> team select -> dashboard)
- [ ] Verify team management works (create, list, switch, invite, manage members)
- [ ] Verify profile screens work (edit profile, avatar, change password)
- [ ] Environment configuration (dev, staging, prod)

**TDD**: All code developed test-first (red-green-refactor). Widget tests for screens, unit tests for state/services.

## What magic_starter Already Provides

The following are **pre-built** and require only configuration, not implementation:

### Auth Screens
- LoginScreen, RegisterScreen, ForgotPasswordScreen, VerifyEmailScreen
- Auth state management via `AuthState` (ChangeNotifier + MagicStateMixin)
- Token storage via `Vault` (cross-platform secure storage)
- Auto-redirect on 401

### Team Screens
- TeamListScreen, CreateTeamScreen, TeamSwitchWidget
- InviteMemberScreen, ManageMembersScreen
- Team context management (persisted selection via Vault)

### Profile Screens
- EditProfileScreen, AvatarUploadWidget, ChangePasswordScreen

### Layout
- Responsive app shell: sidebar (desktop) / drawer + bottom nav (mobile)
- Header with team switcher, notifications, user menu
- Go Router with auth middleware and team guards

### Infrastructure
- `Http` facade (Dio-based) with auth interceptor, error handling, retry
- `Vault` for secure token/preference storage
- DI system for provider injection
- `MagicStateMixin` for standardized loading/error states on ChangeNotifier classes

## Configuration Tasks

### 1. Project Initialization

```bash
# magic_starter provides the project scaffold
flutter create kodizm --platforms=web,ios,android --org=com.kodizm
# Then integrate magic + magic_starter packages
```

### 2. Feature Flag Configuration

Configure which magic_starter features are enabled for Kodizm:

```dart
// config/magic_config.dart
MagicStarter.configure(
  appName: 'Kodizm',
  features: MagicFeatures(
    auth: true,           // Login, Register, Forgot Password, Verify Email
    teams: true,          // Team CRUD, switching, member management
    profile: true,        // Profile editing, avatar, password change
    notifications: true,  // In-app notifications
  ),
  api: ApiConfig(
    baseUrl: Env.apiBaseUrl,
  ),
);
```

### 3. Theme & Branding

```dart
// config/theme.dart — Kodizm-specific theme overrides
MagicStarter.setTheme(
  MagicTheme(
    primaryColor: KodizmColors.primary,
    secondaryColor: KodizmColors.secondary,
    fontFamily: 'Inter',
    logo: 'assets/kodizm_logo.svg',
    darkMode: true, // default to dark mode (developer tool)
  ),
);
```

### 4. Go Router Route Registration

Magic provides default routes for auth, team, and profile. Kodizm-specific routes are registered alongside:

```dart
// config/routes.dart — Kodizm-specific routes
final kodizmRoutes = [
  GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),

  GoRoute(path: '/projects', builder: (_, __) => const ProjectListScreen()),
  GoRoute(path: '/projects/create', builder: (_, __) => const ProjectCreateScreen()),
  GoRoute(path: '/projects/:projectId', builder: (_, state) => ProjectDetailScreen(
    projectId: state.pathParameters['projectId']!,
  )),

  GoRoute(path: '/projects/:projectId/tasks', builder: (_, state) => TaskListScreen(
    projectId: state.pathParameters['projectId']!,
  )),
  GoRoute(path: '/projects/:projectId/tasks/create', builder: (_, state) => TaskCreateScreen(
    projectId: state.pathParameters['projectId']!,
  )),
  GoRoute(path: '/projects/:projectId/tasks/:taskId', builder: (_, state) => TaskDetailScreen(
    projectId: state.pathParameters['projectId']!,
    taskId: state.pathParameters['taskId']!,
  )),

  GoRoute(path: '/projects/:projectId/tasks/:taskId/runs/:runId', builder: (_, state) => AgentRunScreen(
    projectId: state.pathParameters['projectId']!,
    taskId: state.pathParameters['taskId']!,
    runId: state.pathParameters['runId']!,
  )),

  GoRoute(path: '/projects/:projectId/knowledge', builder: (_, state) => KnowledgeListScreen(
    projectId: state.pathParameters['projectId']!,
  )),
  GoRoute(path: '/projects/:projectId/knowledge/:documentId', builder: (_, state) => KnowledgeDetailScreen(
    projectId: state.pathParameters['projectId']!,
    documentId: state.pathParameters['documentId']!,
  )),

  GoRoute(path: '/billing', builder: (_, __) => const BillingScreen()),
  GoRoute(path: '/usage', builder: (_, __) => const UsageHistoryScreen()),
  GoRoute(path: '/settings', builder: (_, __) => const AppSettingsScreen()),
];

// Register with magic's router
MagicStarter.registerRoutes(kodizmRoutes);
```

### 5. WebSocket Service

WebSocket is NOT provided by magic — Kodizm needs its own service for Reverb integration:

```dart
// core/websocket/websocket_service.dart — Singleton
class WebSocketService {
  WebSocketChannel? _channel;
  final Map<String, Set<Function>> _subscriptions = {};
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  static const _maxReconnectDelay = Duration(seconds: 30);

  /// Connect to Laravel Reverb
  Future<void> connect({
    required String wsUrl,
    required String authToken,
  });

  /// Subscribe to a private channel
  StreamSubscription subscribe(
    String channel,
    void Function(Map<String, dynamic> event) onEvent,
  );

  /// Unsubscribe from channel
  void unsubscribe(String channel);

  /// Disconnect
  void disconnect();
}
```

- Auto-reconnect with exponential backoff: `min(2^attempt * 1s, 30s)`
- Resubscribe to all active channels on reconnect
- Event deduplication by event ID (ring buffer, size 100)
- Private channel auth via Sanctum token

### 6. Environment Configuration

```dart
// config/env.dart
class Env {
  static String get apiBaseUrl => const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  static String get wsUrl => const String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080',
  );

  static String get wsAppKey => const String.fromEnvironment(
    'WS_APP_KEY',
    defaultValue: 'kodizm-local',
  );
}
```

Build with: `flutter run --dart-define=API_BASE_URL=https://api.kodizm.com`

## Directory Structure (Kodizm-specific additions)

```
lib/
├── main.dart
├── app.dart                          # MagicStarter.run() entry point
├── config/
│   ├── env.dart                      # Environment variables
│   ├── magic_config.dart             # magic_starter feature flags
│   ├── theme.dart                    # Kodizm theme overrides
│   └── routes.dart                   # Kodizm-specific route definitions
├── core/
│   ├── websocket/
│   │   ├── websocket_service.dart    # Singleton WebSocket manager
│   │   ├── websocket_event.dart      # Event model + deserialization
│   │   └── channel_subscription.dart # Channel subscribe/unsubscribe
│   └── extensions/                   # Dart extensions
├── features/
│   ├── project/                      # Wave 2
│   ├── task/                         # Wave 3
│   ├── agent_run/                    # Wave 4
│   ├── knowledge/                    # Wave 5
│   ├── billing/                      # Wave 6
│   └── dashboard/                    # Wave 2
├── shared/
│   └── widgets/                      # Reusable UI components
```

## Acceptance Criteria

### App Boot

**Given** a fresh clone of the Flutter project,
**When** `flutter pub get` and `flutter run -d chrome` are executed,
**Then** the app compiles and displays the magic_starter login screen with Kodizm branding.

**Given** the Flutter project,
**When** `flutter run -d ios` or `flutter run -d android` is executed,
**Then** the app compiles and displays the login screen on the mobile simulator.

### Auth Flow Verification

**Given** the magic_starter auth screens are configured,
**When** a user logs in with valid credentials,
**Then** the Sanctum token is stored in Vault, auth state transitions to authenticated, and the user is navigated to team selection (or dashboard if a team is already selected).

**Given** the magic_starter auth screens are configured,
**When** a user registers with valid data,
**Then** a new account is created, the token is stored, and the user is navigated to team creation flow.

**Given** an authenticated user with a stored token,
**When** the app starts,
**Then** the auth state validates the token by calling GET `/api/auth/user`. If valid, the user sees the app. If invalid (401), the token is cleared and the user sees the login screen.

### Team Flow Verification

**Given** the magic_starter team screens are configured,
**When** a user creates a new team,
**Then** the team is auto-selected and the user is navigated to the dashboard.

**Given** a user who belongs to multiple teams,
**When** they switch teams via the magic_starter team picker,
**Then** all team-scoped data refreshes and the dashboard shows data for the newly selected team.

**Given** a user who switches teams and restarts the app,
**When** the app starts,
**Then** the last selected team is restored from Vault.

### Profile Flow Verification

**Given** the magic_starter profile screens are configured,
**When** a user updates their name and saves,
**Then** the profile is updated via API.

**Given** the magic_starter change password screen,
**When** a user provides a valid current password and new password,
**Then** the password is updated.

### WebSocket

**Given** an authenticated user,
**When** the WebSocket service connects to Reverb,
**Then** the connection is established and authenticated with the Sanctum token.

**Given** an active WebSocket connection that drops,
**When** the disconnect is detected,
**Then** the service attempts reconnection with exponential backoff (1s, 2s, 4s, 8s... up to 30s max).

**Given** a reconnected WebSocket,
**When** the connection is restored,
**Then** all previously active channel subscriptions are re-established.

**Given** a duplicate event received (same event ID),
**When** the event is processed,
**Then** it is silently dropped (dedup by event ID).

### Routing

**Given** Kodizm-specific routes are registered with magic's router,
**When** a user navigates to `/projects`,
**Then** the ProjectListScreen is displayed (not a 404).

**Given** an unauthenticated user,
**When** they try to navigate to `/dashboard`,
**Then** magic's auth middleware redirects to `/login`.

**Given** an authenticated user with no team selected,
**When** they navigate to `/dashboard`,
**Then** magic's team middleware redirects to `/teams`.

## Implementation Notes

- Do NOT reimplement auth, team, or profile screens — they come from magic_starter.
- All customization is via configuration (feature flags, theme, route registration).
- Use `Http` facade for ALL HTTP calls — never instantiate Dio directly.
- Use `Vault` for ALL secure storage — never use flutter_secure_storage directly.
- All state classes: `class XState extends ChangeNotifier with MagicStateMixin { ... }`
- All model IDs are `String` (UUID) — never use `int` for IDs.
- Theme: dark mode by default (developer tool aesthetic), Material 3 design tokens.
- All strings should be English — no i18n in MVP, but use `intl` for date/number formatting.
