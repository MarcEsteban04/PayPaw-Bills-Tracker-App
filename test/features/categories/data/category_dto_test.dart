import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paypaw/features/categories/data/dtos/category_dto.dart';
import 'package:paypaw/features/categories/domain/entities/category.dart';
import 'package:paypaw/features/categories/presentation/widgets/category_icon.dart';

void main() {
  Map<String, dynamic> row({
    Object? userId,
    Object? colorHex = '#F59E0B',
    Object? sortOrder = 10,
  }) => <String, dynamic>{
    'id': 'cat-1',
    'user_id': userId,
    'name': 'Electricity',
    'icon_name': 'bolt',
    'color_hex': colorHex,
    'sort_order': sortOrder,
  };

  group('reading a row', () {
    test('maps every field', () {
      final Category category = CategoryDto.toEntity(row());

      expect(category.id, 'cat-1');
      expect(category.name, 'Electricity');
      expect(category.iconName, 'bolt');
      expect(category.colorHex, '#F59E0B');
      expect(category.sortOrder, 10);
    });

    test('a null user_id means a shared category', () {
      // The one nullable ownership column in the schema, and the whole reason
      // the read policy differs from the write policies.
      expect(CategoryDto.toEntity(row()).isSystem, isTrue);
      expect(CategoryDto.toEntity(row(userId: 'user-1')).isSystem, isFalse);
    });

    test('a missing sort order is tolerated', () {
      // The column has a default, so a row without it is possible — and an
      // unordered category is a cosmetic problem, not a reason to fail the list
      // the picker needs.
      expect(CategoryDto.toEntity(row(sortOrder: null)).sortOrder, 0);
      expect(CategoryDto.toEntity(row(sortOrder: '20')).sortOrder, 20);
    });

    test('a null colour is allowed', () {
      // Means "use the palette", per the column comment.
      expect(CategoryDto.toEntity(row(colorHex: null)).colorHex, isNull);
    });

    test('throws on a row that cannot be a category', () {
      for (final String missing in <String>['id', 'name', 'icon_name']) {
        expect(
          () => CategoryDto.toEntity(row()..remove(missing)),
          throwsA(isA<FormatException>()),
          reason: 'a row without $missing should be rejected',
        );
      }
    });
  });

  group('column names against migration 0004', () {
    late String sql;

    setUpAll(() {
      final File file = File('supabase/migrations/0004_categories.sql');
      expect(file.existsSync(), isTrue, reason: '${file.path} is missing');
      sql = file.readAsStringSync();
    });

    test('every column exists in the table', () {
      for (final String column in <String>[
        CategoryDto.columnId,
        CategoryDto.columnUserId,
        CategoryDto.columnName,
        CategoryDto.columnIconName,
        CategoryDto.columnColorHex,
        CategoryDto.columnSortOrder,
      ]) {
        expect(
          sql,
          contains(column),
          reason: '$column is read but not declared in 0004_categories.sql',
        );
      }
    });

    test('the table name matches', () {
      expect(sql, contains('public.${CategoryDto.tableName}'));
    });

    test('every seeded icon name resolves to a real icon', () {
      // The check that matters most in this file. Flutter tree-shakes the icon
      // font, so an identifier with no explicit `Icons.` reference in the source
      // renders as an empty box in a release build while looking perfect in
      // debug. Reading the names out of the migration means adding a category
      // there without adding it to the switch fails here rather than on a phone.
      final Iterable<String> seeded = RegExp(r"'([a-z_]+)',\s+'#[0-9A-F]{6}'")
          .allMatches(sql)
          .map((RegExpMatch match) => match.group(1)!);

      expect(
        seeded,
        hasLength(13),
        reason: 'expected the thirteen seeded rows; the regex may have drifted',
      );

      for (final String iconName in seeded) {
        expect(
          CategoryIcons.forName(iconName),
          isNot(CategoryIcons.fallback),
          reason: "'$iconName' is seeded but has no entry in CategoryIcons",
        );
      }
    });
  });

  group('CategoryIcons', () {
    test('an unknown identifier falls back rather than throwing', () {
      // A category added to the database by hand should show a generic icon, not
      // crash the picker.
      expect(CategoryIcons.forName('rocket_launch'), CategoryIcons.fallback);
      expect(CategoryIcons.forName(''), CategoryIcons.fallback);
    });

    test('parses a hex colour', () {
      expect(CategoryIcons.parseColor('#F59E0B'), const Color(0xFFF59E0B));
      expect(CategoryIcons.parseColor('#000000'), const Color(0xFF000000));
    });

    test('returns null for anything malformed', () {
      // Null means "use the palette", so a bad value degrades to the app's own
      // accent rather than to a transparent icon.
      for (final String? hex in <String?>[
        null,
        '',
        'F59E0B',
        '#F59E0',
        '#GGGGGG',
        '#F59E0BB',
      ]) {
        expect(
          CategoryIcons.parseColor(hex),
          isNull,
          reason: '"$hex" should not parse',
        );
      }
    });
  });
}
