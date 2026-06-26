// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../constants/db_keys.dart';
import '../../../utils/mixin/shared_preferences_client_mixin.dart';

part 'onboarding_complete.g.dart';

/// Whether the first-time onboarding wizard has been finished. While false, the
/// router sends every route to `/onboarding`. Persisted in SharedPreferences;
/// a one-time launch migration seeds it true for already-configured installs.
@riverpod
class OnboardingComplete extends _$OnboardingComplete
    with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.onboardingComplete);
}

/// Whether a saved server URL counts as "already configured" for the one-time
/// onboarding migration — anything but unset/empty or the default loopback.
/// Existing installs that pass this are seeded onboarded so the wizard never
/// shows for them.
bool serverConfiguredForOnboarding(String? serverUrl) =>
    serverUrl != null &&
    serverUrl.isNotEmpty &&
    serverUrl != DBKeys.serverUrl.initial;
