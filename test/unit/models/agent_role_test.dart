import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/agent_role.dart';

void main() {
  group('AgentRole', () {
    // -------

    const Map<String, dynamic> fullFixture = {
      'id': 'role-uuid-1',
      'name': 'Business Analyst',
      'description': 'Gathers requirements and writes analysis sections.',
      'scope': 'analysis',
    };

    const Map<String, dynamic> noDescriptionFixture = {
      'id': 'role-uuid-2',
      'name': 'Developer',
      'description': null,
      'scope': 'implementation',
    };

    // -------

    test('fromMap parses all fields correctly', () {
      final role = AgentRole.fromMap(fullFixture);

      expect(role.id, 'role-uuid-1');
      expect(role.name, 'Business Analyst');
      expect(
        role.description,
        'Gathers requirements and writes analysis sections.',
      );
      expect(role.scope, 'analysis');
    });

    test('fromMap handles null description', () {
      final role = AgentRole.fromMap(noDescriptionFixture);

      expect(role.id, 'role-uuid-2');
      expect(role.name, 'Developer');
      expect(role.description, isNull);
      expect(role.scope, 'implementation');
    });

    test('constructor produces correct field values', () {
      const role = AgentRole(
        id: 'role-uuid-3',
        name: 'QA Engineer',
        description: null,
        scope: 'testing',
      );

      expect(role.id, 'role-uuid-3');
      expect(role.name, 'QA Engineer');
      expect(role.description, isNull);
      expect(role.scope, 'testing');
    });
  });
}
