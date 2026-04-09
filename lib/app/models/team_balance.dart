/// The current billing balance and execution limits for a team.
///
/// Maps to the balance payload returned by the Kodizm API. The [balance] field
/// is a decimal string on the wire (e.g. `"100.00"`) and is parsed to a
/// [double] on construction.
///
/// ## Usage
/// ```dart
/// final balance = TeamBalance.fromMap(json['balance']);
/// print('\$${balance.balance} ${balance.currency}');
/// print('Max runs: ${balance.maxConcurrentRuns}');
/// ```
class TeamBalance {
  // -------

  /// Creates a [TeamBalance] with all fields.
  const TeamBalance({
    required this.balance,
    required this.currency,
    required this.maxConcurrentRuns,
  });

  // -------

  /// Current account balance in the team's [currency], parsed from a decimal
  /// string returned by the API (e.g. `"100.00"`).
  final double balance;

  /// ISO 4217 currency code (e.g. `'USD'`).
  final String currency;

  /// Maximum number of task runs the team may execute concurrently.
  final int maxConcurrentRuns;

  // -------

  /// Parses a [TeamBalance] from a JSON-decoded map.
  ///
  /// [balance] is parsed via [double.tryParse] because the API returns it as a
  /// decimal string (e.g. `"100.00"`).
  factory TeamBalance.fromMap(Map<String, dynamic> map) {
    return TeamBalance(
      balance: double.tryParse(map['balance']?.toString() ?? '') ?? 0.0,
      currency: map['currency'] as String,
      maxConcurrentRuns: map['max_concurrent_runs'] as int,
    );
  }
}
