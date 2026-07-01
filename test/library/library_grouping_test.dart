// Tests for the pure groupLibrary() function.
// No GraphQL, no providers — just lightweight fake data.

import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiru/src/features/library/domain/library_group.dart';
import 'package:tsumiru/src/features/library/presentation/library/controller/library_grouping.dart';

// ───────────────────────── fakes ─────────────────────────

/// Minimal stand-in for MangaDto for pure grouping tests.
class _Manga {
  final int id;
  final String sourceId;
  final String sourceName;
  final String sourceLang;
  final String status;
  final List<int> categoryIds;

  const _Manga({
    required this.id,
    this.sourceId = 'src1',
    this.sourceName = 'Source 1',
    this.sourceLang = 'en',
    this.status = 'ONGOING',
    this.categoryIds = const [],
  });
}

/// Minimal stand-in for CategoryDto.
class _Category {
  final int id;
  final String name;

  const _Category({required this.id, required this.name});
}

// Adapters so the fake types satisfy the groupLibrary signature
// (which works on duck-typed records from this test context).
// We use the real groupLibrary via the exported MangaProxy / CategoryProxy
// typedefs, but for this test we define local helpers.

MangaProxy _proxy(_Manga m) => (
      id: m.id,
      sourceId: m.sourceId,
      sourceName: m.sourceName,
      sourceLang: m.sourceLang,
      status: m.status,
      categoryIds: m.categoryIds,
      trackStatuses: const [],
    );

CategoryProxy _catProxy(_Category c) => (id: c.id, name: c.name);

// ──────────────────────── tests ──────────────────────────

void main() {
  group('groupLibrary — BY_SOURCE', () {
    test('buckets manga by sourceId', () {
      final mangas = [
        _proxy(_Manga(id: 1, sourceId: 'a', sourceName: 'Zebra', sourceLang: 'en')),
        _proxy(_Manga(id: 2, sourceId: 'b', sourceName: 'Alpha', sourceLang: 'en')),
        _proxy(_Manga(id: 3, sourceId: 'a', sourceName: 'Zebra', sourceLang: 'en')),
      ];
      final tabs = groupLibrary(mangas, LibraryGroup.bySource, []);
      // Two distinct sources
      expect(tabs.length, 2);
      // Each manga is in exactly one tab
      final allIds = tabs.expand((t) => t.mangaIds).toList();
      expect(allIds..sort(), [1, 2, 3]..sort());
    });

    test('sorts source tabs case-insensitively by name', () {
      final mangas = [
        _proxy(_Manga(id: 1, sourceId: 'z', sourceName: 'zebra', sourceLang: 'en')),
        _proxy(_Manga(id: 2, sourceId: 'a', sourceName: 'Alpha', sourceLang: 'en')),
        _proxy(_Manga(id: 3, sourceId: 'm', sourceName: 'middle', sourceLang: 'en')),
      ];
      final tabs = groupLibrary(mangas, LibraryGroup.bySource, []);
      expect(tabs.map((t) => t.name).toList(),
          ['Alpha', 'middle', 'zebra']);
    });

    test('local source named "Local source"', () {
      final mangas = [
        _proxy(_Manga(
          id: 1,
          sourceId: 'local1',
          sourceName: 'Local',
          sourceLang: 'localsourcelang',
        )),
      ];
      final tabs = groupLibrary(mangas, LibraryGroup.bySource, []);
      expect(tabs.single.name, 'Local source');
    });
  });

  group('groupLibrary — BY_STATUS', () {
    test('orders tabs by statusOrder', () {
      final mangas = [
        _proxy(_Manga(id: 1, status: 'UNKNOWN')),
        _proxy(_Manga(id: 2, status: 'COMPLETED')),
        _proxy(_Manga(id: 3, status: 'ONGOING')),
        _proxy(_Manga(id: 4, status: 'ON_HIATUS')),
      ];
      final tabs = groupLibrary(mangas, LibraryGroup.byStatus, []);
      expect(tabs.map((t) => t.name).toList(),
          ['Ongoing', 'Completed', 'On hiatus', 'Unknown']);
    });

    test('unknown status falls back to UNKNOWN bucket', () {
      final mangas = [
        _proxy(_Manga(id: 1, status: 'SOME_WEIRD_STATUS')),
      ];
      final tabs = groupLibrary(mangas, LibraryGroup.byStatus, []);
      expect(tabs.single.name, 'Unknown');
    });
  });

  group('groupLibrary — BY_DEFAULT', () {
    test('fans a 2-category manga into both tabs', () {
      final cats = [
        _catProxy(_Category(id: 1, name: 'Favorites')),
        _catProxy(_Category(id: 2, name: 'Reading')),
      ];
      final mangas = [
        _proxy(_Manga(id: 99, categoryIds: [1, 2])),
      ];
      final tabs = groupLibrary(mangas, LibraryGroup.byDefault, cats);
      // Should appear in both cat 1 and cat 2 tabs
      final tabWithCat1 = tabs.firstWhere((t) => t.id == 1);
      final tabWithCat2 = tabs.firstWhere((t) => t.id == 2);
      expect(tabWithCat1.mangaIds, contains(99));
      expect(tabWithCat2.mangaIds, contains(99));
    });

    test('no-category manga appears under id 0', () {
      final cats = [
        _catProxy(_Category(id: 1, name: 'Cat A')),
      ];
      final mangas = [
        _proxy(_Manga(id: 7, categoryIds: [])),
      ];
      final tabs = groupLibrary(mangas, LibraryGroup.byDefault, cats);
      final defaultTab = tabs.firstWhere((t) => t.id == 0);
      expect(defaultTab.mangaIds, contains(7));
    });
  });

  group('groupLibrary — UNGROUPED', () {
    test('yields exactly one tab containing all manga', () {
      final mangas = [
        _proxy(_Manga(id: 1)),
        _proxy(_Manga(id: 2)),
        _proxy(_Manga(id: 3)),
      ];
      final tabs = groupLibrary(mangas, LibraryGroup.ungrouped, []);
      expect(tabs.length, 1);
      expect(tabs.single.mangaIds..sort(), [1, 2, 3]);
    });
  });
}
