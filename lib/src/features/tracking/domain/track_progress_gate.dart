// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../utils/extensions/custom_extensions.dart';
import '../../../utils/misc/toast/toast.dart';
import '../controller/manga_track_records_controller.dart';
import '../data/tracker_repository.dart';
import 'tracking_settings_providers.dart';

/// Pure predicate — no Flutter / Riverpod deps, so it is trivially unit-testable.
///
/// Returns true when all of the following hold:
///   * [isRead] — the chapter was just marked read.
///   * [trackRecordCount] > 0 — at least one tracker is bound to the manga.
///   * The relevant toggle is on:
///       - auto path ([manual] == false) → [enabledAfterReading]
///       - manual-mark-read path ([manual] == true) → [enabledManualMarkRead]
bool shouldTrackProgress({
  required bool isRead,
  required bool enabledAfterReading,
  required bool enabledManualMarkRead,
  required bool manual,
  required int trackRecordCount,
}) =>
    isRead &&
    trackRecordCount > 0 &&
    (manual ? enabledManualMarkRead : enabledAfterReading);

/// Wiring helper — reads toggle settings, fetches the track-record count for
/// [mangaId] from the Riverpod cache, and fires
/// [TrackerRepository.trackProgress] when [shouldTrackProgress] is true.
///
/// Fire-and-forget: errors are surfaced as an error toast and swallowed so
/// that a tracker hiccup never interrupts the reading experience.
Future<void> maybeTrackProgressOnRead(
  WidgetRef ref, {
  required int mangaId,
  required bool isRead,
  required bool manual,
  required int trackRecordCount,
}) async {
  final enabledAfterReading =
      ref.read(updateProgressAfterReadingProvider).ifNull();
  final enabledManualMarkRead =
      ref.read(updateProgressManualMarkReadProvider).ifNull();

  if (!shouldTrackProgress(
    isRead: isRead,
    enabledAfterReading: enabledAfterReading,
    enabledManualMarkRead: enabledManualMarkRead,
    manual: manual,
    trackRecordCount: trackRecordCount,
  )) {
    return;
  }

  final result = await AsyncValue.guard(
    () => ref.read(trackerRepositoryProvider).trackProgress(mangaId),
  );
  result.showToastOnError(ref.read(toastProvider), withMicrotask: true);
}

/// Convenience overload for call sites that don't have the track-record count
/// in scope. Looks it up via [mangaTrackRecordsProvider] (uses cached value;
/// does not issue a new network request if already loaded).
Future<void> maybeTrackProgressOnReadFetch(
  WidgetRef ref, {
  required int mangaId,
  required bool isRead,
  required bool manual,
}) async {
  final records =
      ref.read(mangaTrackRecordsProvider(mangaId: mangaId)).valueOrNull ?? [];
  await maybeTrackProgressOnRead(
    ref,
    mangaId: mangaId,
    isRead: isRead,
    manual: manual,
    trackRecordCount: records.length,
  );
}
