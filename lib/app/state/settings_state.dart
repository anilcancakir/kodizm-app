import 'package:flutter/foundation.dart';
import 'package:magic/magic.dart';

// ---------------------------------------------------------------------------
// Vault abstraction for testability
// ---------------------------------------------------------------------------

/// Thin key/value interface over secure storage used by [SettingsState].
///
/// The production implementation delegates to [Vault].
/// Tests inject an in-memory fake.
abstract class SettingsStorage {
  /// Retrieve a stored string, or `null` if the key does not exist.
  Future<String?> get(String key);

  /// Persist a string value under [key].
  Future<void> put(String key, String value);
}

/// Default production [SettingsStorage] backed by the Magic [Vault] facade.
class _VaultStorage implements SettingsStorage {
  const _VaultStorage();

  @override
  Future<String?> get(String key) => Vault.get(key);

  @override
  Future<void> put(String key, String value) => Vault.put(key, value);
}

// ---------------------------------------------------------------------------
// SettingsState
// ---------------------------------------------------------------------------

/// Reactive state holder for user notification preferences.
///
/// All preferences are persisted to secure storage via [SettingsStorage]
/// (production: [Vault]) and exposed as boolean getters that default to
/// `true` when no stored value exists.
///
/// This class extends [ChangeNotifier] directly because it has no HTTP calls
/// and does not need [MagicStateMixin]'s loading/error/success machinery.
///
/// ## Usage
///
/// ```dart
/// // Initialise once (e.g. in AppSettingsView.initState).
/// await SettingsState.instance.init();
///
/// // Read a preference.
/// final notify = SettingsState.instance.notifyRunCompleted;
///
/// // Toggle a preference.
/// await SettingsState.instance.setNotificationPref(
///   SettingsState.keyRunCompleted,
///   false,
/// );
/// ```
class SettingsState extends ChangeNotifier {
  /// Creates a [SettingsState] with an optional [storage] for testing.
  ///
  /// When [storage] is `null` (production), [Vault] is used via
  /// [_VaultStorage].
  SettingsState({SettingsStorage? storage})
    : _storage = storage ?? const _VaultStorage();

  /// Singleton instance.
  static final SettingsState instance = SettingsState();

  final SettingsStorage _storage;

  // ---------------------------------------------------------------------------
  // Vault key constants
  // ---------------------------------------------------------------------------

  /// Vault key — notify when an agent run completes.
  static const String keyRunCompleted = 'settings.notify_run_completed';

  /// Vault key — notify when an agent run fails.
  static const String keyRunFailed = 'settings.notify_run_failed';

  /// Vault key — notify when a question is pending human review.
  static const String keyQuestionPending = 'settings.notify_question_pending';

  /// Vault key — notify when the billing balance is low.
  static const String keyBalanceLow = 'settings.notify_balance_low';

  // ---------------------------------------------------------------------------
  // In-memory cache
  // ---------------------------------------------------------------------------

  final Map<String, bool> _prefs = {};

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Load all notification preferences from secure storage.
  ///
  /// Absent keys default to `true`. Must be awaited before reading getters
  /// for the first time (e.g. in a view's `initState`).
  Future<void> init() async {
    _prefs[keyRunCompleted] = await _readBool(keyRunCompleted);
    _prefs[keyRunFailed] = await _readBool(keyRunFailed);
    _prefs[keyQuestionPending] = await _readBool(keyQuestionPending);
    _prefs[keyBalanceLow] = await _readBool(keyBalanceLow);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Notification preference getters
  // ---------------------------------------------------------------------------

  /// Whether to notify the user when an agent run completes successfully.
  bool get notifyRunCompleted => _prefs[keyRunCompleted] ?? true;

  /// Whether to notify the user when an agent run fails.
  bool get notifyRunFailed => _prefs[keyRunFailed] ?? true;

  /// Whether to notify the user when a question is pending human review.
  bool get notifyQuestionPending => _prefs[keyQuestionPending] ?? true;

  /// Whether to notify the user when their billing balance is low.
  bool get notifyBalanceLow => _prefs[keyBalanceLow] ?? true;

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Persist a notification preference and notify listeners.
  ///
  /// [key] must be one of the `key*` constants defined on this class.
  /// [value] is stored as `'true'` or `'false'` in secure storage.
  Future<void> setNotificationPref(String key, bool value) async {
    await _storage.put(key, value.toString());
    _prefs[key] = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Read a stored boolean; defaults to `true` when the key is absent.
  Future<bool> _readBool(String key) async {
    final stored = await _storage.get(key);
    if (stored == null) return true;
    return stored == 'true';
  }
}
