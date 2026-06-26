// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:network_info_plus/network_info_plus.dart';

/// LAN discovery for the onboarding "Search my network" action.
///
/// Sweeps the device's Wi-Fi /24 subnet looking for a Suwayomi server on its
/// default port (4567) — the same approach as the existing ServerSearchButton,
/// extracted so onboarding can drive it. The Wi-Fi-IP lookup and the per-host
/// ping are injectable so the sweep logic is unit-testable without a network.

const int kSuwayomiScanPort = 4567;

/// Every host to probe for [ip]'s /24 subnet (`x.y.z.1` … `x.y.z.254`), plus
/// [ip] itself, de-duplicated and order-preserving.
List<String> subnetHosts(String ip) {
  final dot = ip.lastIndexOf('.');
  if (dot < 0) return [ip];
  final subnet = ip.substring(0, dot);
  return <String>{ip, for (var i = 1; i < 255; i++) '$subnet.$i'}.toList();
}

/// Scans the Wi-Fi subnet for a Suwayomi server on :4567. Returns
/// `http://<ip>:4567` for the first host that accepts a TCP connection there,
/// or null if none (or there's no Wi-Fi IP). Probes in concurrent batches so a
/// full /24 sweep finishes quickly.
Future<String?> discoverServerOnLan({
  Future<String?> Function()? wifiIp,
  Future<bool> Function(String host, int port)? ping,
  int batchSize = 48,
}) async {
  final ip = await (wifiIp ?? () => NetworkInfo().getWifiIP())();
  if (ip == null || ip.isEmpty) return null;

  final doPing = ping ?? _ping;
  final hosts = subnetHosts(ip);
  for (var start = 0; start < hosts.length; start += batchSize) {
    final end =
        (start + batchSize) < hosts.length ? start + batchSize : hosts.length;
    final batch = hosts.sublist(start, end);
    final results = await Future.wait(
        batch.map((h) async => (await doPing(h, kSuwayomiScanPort)) ? h : null));
    for (final h in results) {
      if (h != null) return 'http://$h:$kSuwayomiScanPort';
    }
  }
  return null;
}

Future<bool> _ping(String host, int port) async {
  try {
    final socket = await Socket.connect(host, port,
        timeout: const Duration(milliseconds: 120));
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
