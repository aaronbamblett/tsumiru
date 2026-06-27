// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/graphql/__generated__/query.graphql.dart';
import '../data/tracker_repository.dart';

part 'tracker_search_controller.g.dart';

@riverpod
Future<List<Fragment$TrackSearchDto>> searchTracker(
  Ref ref, {
  required int trackerId,
  required String query,
}) async {
  final repo = ref.watch(trackerRepositoryProvider);
  return await repo.search(trackerId: trackerId, query: query) ?? [];
}
