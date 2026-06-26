// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../constants/db_keys.dart';
import '../../../../constants/endpoints.dart';
import '../../../../constants/enum.dart';
import '../../../../features/auth/data/auth_coordinator.dart';
import '../../../../features/auth/data/auth_credentials_store.dart';
import '../../../../features/auth/data/auth_state.dart';
import '../../../../global_providers/global_providers.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/section_title.dart';
import '../server/widget/client/server_port_tile/server_port_tile.dart';
import '../server/widget/client/server_url_tile/server_url_tile.dart';
import '../server/widget/credential_popup/credentials_popup.dart';
import '../server/widget/credential_popup/login_credentials_popup.dart';

/// Inline sign-in on the Connection screen — auth mode + username + password +
/// a Sign in button, the same shape as the first-run (FTUE) server step,
/// instead of hiding credentials behind a dialog.
class InlineAuthSection extends HookConsumerWidget {
  const InlineAuthSection({super.key});

  String _basicAuthHeader(String user, String pass) =>
      'Basic ${base64.encode(utf8.encode('$user:$pass'))}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authType = ref.watch(authTypeKeyProvider) ?? AuthType.none;
    final needsReauth = ref.watch(needsReauthProvider);

    final username = useTextEditingController(
      text: ref.read(authUsernameProvider) ?? '',
    );
    final password = useTextEditingController();
    final busy = useState(false);
    final message = useState<String?>(null);
    final isError = useState(false);

    String resolvedBaseUrl() => Endpoints.baseApi(
          baseUrl: ref.read(serverUrlProvider) ?? DBKeys.serverUrl.initial,
          port: ref.read(serverPortProvider),
          addPort: ref.read(serverPortToggleProvider).ifNull(),
        );

    Future<void> signIn() async {
      if (username.text.trim().isEmpty || password.text.isEmpty) {
        isError.value = true;
        message.value = context.l10n.onboardingCredsRejected;
        return;
      }
      busy.value = true;
      message.value = null;
      try {
        final store = ref.read(authCredentialsStoreProvider.notifier);
        ref.read(authUsernameProvider.notifier).update(username.text.trim());
        switch (authType) {
          case AuthType.basic:
            await store.clearUiLoginTokens();
            await store.clearSimpleLoginCookie();
            await ref.read(credentialsProvider.notifier).set(
                  _basicAuthHeader(username.text.trim(), password.text),
                );
          case AuthType.simpleLogin:
            await store.clearUiLoginTokens();
            await store.clearBasicCredentials();
            await ref.read(authCoordinatorProvider.notifier).loginSimple(
                  serverBaseUrl: resolvedBaseUrl(),
                  username: username.text.trim(),
                  password: password.text,
                );
          case AuthType.uiLogin:
            await store.clearSimpleLoginCookie();
            await store.clearBasicCredentials();
            await ref.read(authCoordinatorProvider.notifier).loginUi(
                  gqlClient: ref.read(graphQlClientProvider),
                  username: username.text.trim(),
                  password: password.text,
                );
          case AuthType.none:
            break;
        }
        if (!context.mounted) return;
        ref.read(needsReauthProvider.notifier).set(false);
        password.clear();
        isError.value = false;
        message.value = context.l10n.authTestConnectionSuccess;
      } catch (e) {
        if (!context.mounted) return;
        isError.value = true;
        message.value = _failureText(context, classifyAuthError(e).kind);
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    Future<void> logout() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text(context.l10n.authLogout),
          content: Text(context.l10n.authLogoutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(context.l10n.authLogout),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final store = ref.read(authCredentialsStoreProvider.notifier);
      await store.clearUiLoginTokens();
      await store.clearSimpleLoginCookie();
      await store.clearPassword();
      await store.clearBasicCredentials();
      ref.read(authTypeKeyProvider.notifier).update(AuthType.none);
      ref.read(needsReauthProvider.notifier).set(false);
      password.clear();
      message.value = null;
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title: context.l10n.authentication),
        // Auth mode — inline, no dialog.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: DropdownButtonFormField<AuthType>(
            initialValue: authType,
            decoration: InputDecoration(
              labelText: context.l10n.authType,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.security_rounded),
            ),
            items: AuthType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.toLocale(context)),
                    ))
                .toList(),
            onChanged: (t) {
              if (t == null) return;
              ref.read(authTypeKeyProvider.notifier).update(t);
              message.value = null;
            },
          ),
        ),
        if (authType != AuthType.none) ...[
          if (needsReauth)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                context.l10n.connectionAuthSignInNeeded,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: username,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.l10n.userName,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_rounded),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.password,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_rounded),
              ),
              onSubmitted: (_) => signIn(),
            ),
          ),
          if (message.value != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                message.value!,
                style: TextStyle(
                  color: isError.value
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: FilledButton.icon(
              onPressed: busy.value ? null : signIn,
              icon: busy.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(context.l10n.onboardingSignIn),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            title: Text(
              context.l10n.authLogout,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: logout,
          ),
        ],
      ],
    );
  }
}

String _failureText(BuildContext context, TestConnectionFailureKind kind) =>
    switch (kind) {
      TestConnectionFailureKind.network =>
        context.l10n.authTestConnectionFailedNetwork,
      TestConnectionFailureKind.tls =>
        context.l10n.authTestConnectionFailedTls,
      TestConnectionFailureKind.invalidCredentials =>
        context.l10n.authTestConnectionFailedAuth,
      TestConnectionFailureKind.wrongAuthMode =>
        context.l10n.authTestConnectionFailedMode,
      TestConnectionFailureKind.unexpectedShape =>
        context.l10n.authTestConnectionFailedShape,
      TestConnectionFailureKind.insecureTransport =>
        context.l10n.authInsecureTransportWarning,
    };
