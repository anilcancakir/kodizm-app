import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/models/skill.dart';

void main() {
  group('Skill', () {
    final Map<String, dynamic> sampleMap = {
      'id': 'skill-uuid-001',
      'name': 'my-coding',
      'slug': 'my-coding',
      'description': 'Enforce coding style and conventions.',
      'when_to_use': 'Any code generation task.',
      'category': 'coding',
      'body': 'Full skill body content here.',
      'scope': 'global',
      'source': 'marketplace',
      'source_id': 'src-uuid-001',
      'source_url': 'https://skills.example.com/my-coding',
      'is_active': true,
      'sort_order': 1,
    };

    // -------------------------------------------------------------------------
    // fromMap / Factory
    // -------------------------------------------------------------------------

    test('fromMap parses all fields correctly', () {
      final skill = Skill.fromMap(sampleMap);

      expect(skill.id, equals('skill-uuid-001'));
      expect(skill.name, equals('my-coding'));
      expect(skill.slug, equals('my-coding'));
      expect(
        skill.description,
        equals('Enforce coding style and conventions.'),
      );
      expect(skill.whenToUse, equals('Any code generation task.'));
      expect(skill.category, equals('coding'));
      expect(skill.body, equals('Full skill body content here.'));
      expect(skill.scope, equals('global'));
      expect(skill.source, equals('marketplace'));
      expect(skill.sourceId, equals('src-uuid-001'));
      expect(skill.sourceUrl, equals('https://skills.example.com/my-coding'));
      expect(skill.isActive, isTrue);
      expect(skill.sortOrder, equals(1));
      expect(skill.exists, isTrue);
    });

    test('fromMap sets exists=false when id is absent', () {
      final skill = Skill.fromMap({'name': 'unnamed'});
      expect(skill.exists, isFalse);
    });

    test('fromJson delegates to fromMap', () {
      const json = '''
        {
          "id": "skill-uuid-001",
          "name": "my-coding",
          "slug": "my-coding",
          "is_active": true
        }
      ''';

      final skill = Skill.fromJson(json);

      expect(skill.id, equals('skill-uuid-001'));
      expect(skill.name, equals('my-coding'));
      expect(skill.isActive, isTrue);
    });

    // -------------------------------------------------------------------------
    // Typed Accessors — return types
    // -------------------------------------------------------------------------

    test('id returns empty string when null', () {
      final skill = Skill.fromMap({});
      expect(skill.id, equals(''));
    });

    test('isActive defaults to false when absent', () {
      final skill = Skill.fromMap({'id': 'x'});
      expect(skill.isActive, isFalse);
    });

    test('sortOrder returns null when absent', () {
      final skill = Skill.fromMap({'id': 'x'});
      expect(skill.sortOrder, isNull);
    });

    test('nullable string accessors return null when absent', () {
      final skill = Skill.fromMap({'id': 'x'});
      expect(skill.name, isNull);
      expect(skill.slug, isNull);
      expect(skill.description, isNull);
      expect(skill.whenToUse, isNull);
      expect(skill.category, isNull);
      expect(skill.body, isNull);
      expect(skill.scope, isNull);
      expect(skill.source, isNull);
      expect(skill.sourceId, isNull);
      expect(skill.sourceUrl, isNull);
    });

    // -------------------------------------------------------------------------
    // Setters
    // -------------------------------------------------------------------------

    test('setters update attribute values', () {
      final skill = Skill.fromMap({'id': 'skill-uuid-001'});

      skill.name = 'updated-skill';
      skill.isActive = false;
      skill.sortOrder = 5;

      expect(skill.name, equals('updated-skill'));
      expect(skill.isActive, isFalse);
      expect(skill.sortOrder, equals(5));
    });
  });
}
