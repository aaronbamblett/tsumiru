// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/graphql/__generated__/query.graphql.dart';
import '../data/tracker_repository.dart';

part 'manga_track_records_controller.g.dart';

@riverpod
Future<List<Fragment$TrackRecordDto>> mangaTrackRecords(
  Ref ref, {
  required int mangaId,
}) async {
  final repo = ref.watch(trackerRepositoryProvider);
  return await repo.getMangaTrackRecords(mangaId) ?? [];
}
