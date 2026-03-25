import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/team_balance.dart';

void main() {
  group('TeamBalance', () {
    // ---------------------------------------------------------------------------
    // Shared fixture
    // ---------------------------------------------------------------------------

    const Map<String, dynamic> kApiPayload = {
      'balance': '100.00',
      'currency': 'USD',
      'max_concurrent_runs': 5,
    };

    // ---------------------------------------------------------------------------
    // fromMap
    // ---------------------------------------------------------------------------

    test('fromMap hydrates all fields correctly', () {
      final balance = TeamBalance.fromMap(kApiPayload);

      expect(balance.balance, equals(100.00));
      expect(balance.currency, equals('USD'));
      expect(balance.maxConcurrentRuns, equals(5));
    });

    test('fromMap parses balance from decimal string', () {
      final balance = TeamBalance.fromMap(kApiPayload);

      expect(balance.balance, isA<double>());
      expect(balance.balance, equals(100.0));
    });

    test('fromMap parses balance with high precision decimal', () {
      final map = {...kApiPayload, 'balance': '42.123456'};
      final balance = TeamBalance.fromMap(map);

      expect(balance.balance, closeTo(42.123456, 0.000001));
    });

    // ---------------------------------------------------------------------------
    // Edge cases
    // ---------------------------------------------------------------------------

    test('fromMap parses zero balance correctly', () {
      final map = {...kApiPayload, 'balance': '0.00'};
      final balance = TeamBalance.fromMap(map);

      expect(balance.balance, equals(0.0));
    });

    test('fromMap handles maxConcurrentRuns of 1', () {
      final map = {...kApiPayload, 'max_concurrent_runs': 1};
      final balance = TeamBalance.fromMap(map);

      expect(balance.maxConcurrentRuns, equals(1));
    });

    test('fromMap preserves currency code', () {
      final map = {...kApiPayload, 'currency': 'EUR'};
      final balance = TeamBalance.fromMap(map);

      expect(balance.currency, equals('EUR'));
    });
  });
}
