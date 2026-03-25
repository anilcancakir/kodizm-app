import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/file_change.dart';

void main() {
  group('FileChange', () {
    // -------

    const Map<String, dynamic> modifiedFixture = {
      'file_path': 'lib/app/models/task.dart',
      'operation': 'M',
    };

    const Map<String, dynamic> addedFixture = {
      'file_path': 'lib/app/models/file_change.dart',
      'operation': 'A',
    };

    const Map<String, dynamic> deletedFixture = {
      'file_path': 'lib/app/models/old_model.dart',
      'operation': 'D',
    };

    // -------

    test('fromMap parses filePath and operation correctly', () {
      final change = FileChange.fromMap(modifiedFixture);

      expect(change.filePath, 'lib/app/models/task.dart');
      expect(change.operation, 'M');
    });

    test('fromMap parses added operation correctly', () {
      final change = FileChange.fromMap(addedFixture);

      expect(change.filePath, 'lib/app/models/file_change.dart');
      expect(change.operation, 'A');
    });

    test('fromMap parses deleted operation correctly', () {
      final change = FileChange.fromMap(deletedFixture);

      expect(change.filePath, 'lib/app/models/old_model.dart');
      expect(change.operation, 'D');
    });

    test('const constructor sets fields correctly', () {
      const change = FileChange(filePath: 'lib/main.dart', operation: 'M');

      expect(change.filePath, 'lib/main.dart');
      expect(change.operation, 'M');
    });
  });
}
