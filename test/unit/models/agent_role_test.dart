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
      final role = AgentRole(
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

  // -------

  group('AgentRole (full API fields)', () {
    // -------

    const Map<String, dynamic> apiFixture = {
      'id': 'role-uuid-api-1',
      'team_id': 'team-uuid-1',
      'project_id': 'project-uuid-1',
      'parent_id': 'parent-uuid-1',
      'name': 'Business Analyst',
      'slug': 'business-analyst',
      'description': 'Gathers requirements and writes analysis sections.',
      'cli_backend': 'claude',
      'preferred_model': 'claude-sonnet-4-5',
      'backend_config': {'temperature': 0.7, 'max_tokens': 4096},
      'tool_permissions': {'web_search': true, 'code_execution': false},
      'scope': 'analysis',
      'is_active': true,
      'sort_order': 1,
      'created_at': '2025-01-01T00:00:00Z',
      'updated_at': '2025-01-02T00:00:00Z',
    };

    const Map<String, dynamic> nullableFixture = {
      'id': 'role-uuid-api-2',
      'team_id': 'team-uuid-1',
      'project_id': null,
      'parent_id': null,
      'name': 'Developer',
      'slug': 'developer',
      'description': null,
      'cli_backend': 'claude',
      'preferred_model': null,
      'backend_config': null,
      'tool_permissions': null,
      'scope': 'implementation',
      'is_active': true,
      'sort_order': 0,
      'created_at': '2025-01-01T00:00:00Z',
      'updated_at': '2025-01-01T00:00:00Z',
    };

    // -------

    test('fromMap parses all API fields correctly', () {
      final role = AgentRole.fromMap(apiFixture);

      expect(role.id, 'role-uuid-api-1');
      expect(role.teamId, 'team-uuid-1');
      expect(role.projectId, 'project-uuid-1');
      expect(role.parentId, 'parent-uuid-1');
      expect(role.name, 'Business Analyst');
      expect(role.slug, 'business-analyst');
      expect(
        role.description,
        'Gathers requirements and writes analysis sections.',
      );
      expect(role.cliBackend, 'claude');
      expect(role.preferredModel, 'claude-sonnet-4-5');
      expect(role.backendConfig, {'temperature': 0.7, 'max_tokens': 4096});
      expect(role.toolPermissions, {
        'web_search': true,
        'code_execution': false,
      });
      expect(role.scope, 'analysis');
      expect(role.isActive, isTrue);
      expect(role.sortOrder, 1);
      expect(role.createdAt, '2025-01-01T00:00:00Z');
      expect(role.updatedAt, '2025-01-02T00:00:00Z');
    });

    test('fromMap handles null optional fields', () {
      final role = AgentRole.fromMap(nullableFixture);

      expect(role.id, 'role-uuid-api-2');
      expect(role.teamId, 'team-uuid-1');
      expect(role.projectId, isNull);
      expect(role.parentId, isNull);
      expect(role.name, 'Developer');
      expect(role.slug, 'developer');
      expect(role.description, isNull);
      expect(role.cliBackend, 'claude');
      expect(role.preferredModel, isNull);
      expect(role.backendConfig, isNull);
      expect(role.toolPermissions, isNull);
      expect(role.scope, 'implementation');
      expect(role.isActive, isTrue);
      expect(role.sortOrder, 0);
    });

    test('constructor accepts all fields', () {
      final role = AgentRole(
        id: 'role-uuid-api-3',
        teamId: 'team-uuid-2',
        projectId: 'project-uuid-2',
        parentId: null,
        name: 'Lead Developer',
        slug: 'lead-developer',
        description: 'Leads the development team.',
        cliBackend: 'claude',
        preferredModel: 'claude-opus-4-5',
        backendConfig: {'temperature': 0.5},
        toolPermissions: {'code_execution': true},
        scope: 'implementation',
        isActive: true,
        sortOrder: 2,
        createdAt: '2025-02-01T00:00:00Z',
        updatedAt: '2025-02-01T00:00:00Z',
      );

      expect(role.id, 'role-uuid-api-3');
      expect(role.teamId, 'team-uuid-2');
      expect(role.projectId, 'project-uuid-2');
      expect(role.parentId, isNull);
      expect(role.name, 'Lead Developer');
      expect(role.slug, 'lead-developer');
      expect(role.description, 'Leads the development team.');
      expect(role.cliBackend, 'claude');
      expect(role.preferredModel, 'claude-opus-4-5');
      expect(role.backendConfig, {'temperature': 0.5});
      expect(role.toolPermissions, {'code_execution': true});
      expect(role.scope, 'implementation');
      expect(role.isActive, isTrue);
      expect(role.sortOrder, 2);
      expect(role.createdAt, '2025-02-01T00:00:00Z');
      expect(role.updatedAt, '2025-02-01T00:00:00Z');
    });
  });
}
