// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:convert';
import 'dart:io';

sealed class LogEntry {
  const LogEntry();
}

class PageEntry extends LogEntry {
  const PageEntry(this.chapterId, this.mangaId, this.pageIndex, this.relPath, this.bytes);
  final int chapterId, mangaId, pageIndex, bytes;
  final String relPath;
}

class ChapterEntry extends LogEntry {
  const ChapterEntry(this.chapterId, this.status, this.pages, this.bytes);
  final int chapterId, pages, bytes;
  final String status; // downloaded | error | authFailed | offline
}

class DrainedEntry extends LogEntry {
  const DrainedEntry();
}

/// Append-only JSONL record of background-download progress. The DURABLE source
/// of truth the main isolate replays into drift on resume/launch. One JSON object
/// per line, flushed. A torn final line (process killed mid-write) is silently
/// discarded on parse; page files are independently crash-safe (atomic write).
class BackgroundCompletionLog {
  BackgroundCompletionLog(this.file);
  final File file;

  Future<void> _append(Map<String, Object?> obj) async {
    await file.parent.create(recursive: true);
    await file.writeAsString('${jsonEncode(obj)}\n',
        mode: FileMode.append, flush: true);
  }

  Future<void> appendPage({
    required int chapterId,
    required int mangaId,
    required int pageIndex,
    required String relPath,
    required int bytes,
  }) =>
      _append({'t': 'page', 'c': chapterId, 'm': mangaId, 'i': pageIndex, 'p': relPath, 'b': bytes});

  Future<void> appendChapter({
    required int chapterId,
    required String status,
    required int pages,
    required int bytes,
  }) =>
      _append({'t': 'chapter', 'c': chapterId, 's': status, 'pages': pages, 'bytes': bytes});

  Future<void> appendDrained() => _append({'t': 'drained'});

  Future<List<LogEntry>> parse() async {
    if (!await file.exists()) return const [];
    final lines = await file.readAsLines();
    final out = <LogEntry>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      Map<String, Object?> j;
      try {
        j = jsonDecode(line) as Map<String, Object?>;
      } catch (_) {
        continue; // torn/partial line — discard
      }
      switch (j['t']) {
        case 'page':
          out.add(PageEntry(j['c'] as int, j['m'] as int, j['i'] as int, j['p'] as String, j['b'] as int));
        case 'chapter':
          out.add(ChapterEntry(j['c'] as int, j['s'] as String, j['pages'] as int, j['bytes'] as int));
        case 'drained':
          out.add(const DrainedEntry());
      }
    }
    return out;
  }

  Future<void> truncate() async {
    if (await file.exists()) await file.writeAsString('', flush: true);
  }
}
