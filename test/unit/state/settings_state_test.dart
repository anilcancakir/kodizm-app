import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/state/settings_state.dart';

// ---------------------------------------------------------------------------
// In-memory SettingsStorage fake
// ---------------------------------------------------------------------------

class _FakeStorage implements SettingsStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> get(String key) async => _data[key];

  @override
  Future<void> put(String key, String value) async => _data[key] = value;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SettingsState', () {
    late _FakeStorage storage;
    late SettingsState state;

    setUp(() {
      storage = _FakeStorage();
      state = SettingsState(storage: storage);
    });

    test(
      'init defaults all notification prefs to true when Vault is empty',
      () async {
        await state.init();

        expect(state.notifyRunCompleted, isTrue);
        expect(state.notifyRunFailed, isTrue);
        expect(state.notifyQuestionPending, isTrue);
        expect(state.notifyBalanceLow, isTrue);
      },
    );

    test('setNotificationPref updates the corresponding getter', () async {
      await state.init();

      await state.setNotificationPref(SettingsState.keyRunCompleted, false);

      expect(state.notifyRunCompleted, isFalse);
      // Other prefs remain unchanged.
      expect(state.notifyRunFailed, isTrue);
      expect(state.notifyQuestionPending, isTrue);
      expect(state.notifyBalanceLow, isTrue);
    });

    test('setNotificationPref notifies listeners', () async {
      await state.init();

      var notified = false;
      state.addListener(() => notified = true);

      await state.setNotificationPref(SettingsState.keyRunFailed, false);

      expect(notified, isTrue);
    });

    test('multiple prefs can be toggled independently', () async {
      await state.init();

      await state.setNotificationPref(SettingsState.keyRunCompleted, false);
      await state.setNotificationPref(SettingsState.keyQuestionPending, false);

      expect(state.notifyRunCompleted, isFalse);
      expect(state.notifyRunFailed, isTrue);
      expect(state.notifyQuestionPending, isFalse);
      expect(state.notifyBalanceLow, isTrue);
    });

    test('init reads previously persisted values from storage', () async {
      // Pre-populate storage as if a previous session had saved these values.
      await storage.put(SettingsState.keyRunCompleted, 'false');
      await storage.put(SettingsState.keyBalanceLow, 'false');

      await state.init();

      expect(state.notifyRunCompleted, isFalse);
      expect(state.notifyRunFailed, isTrue);
      expect(state.notifyQuestionPending, isTrue);
      expect(state.notifyBalanceLow, isFalse);
    });
  });
}
