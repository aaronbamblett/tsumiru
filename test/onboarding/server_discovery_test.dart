// Copyright (c) 2026 Contributors to the Suwayomi project
//
// Unit tests for LAN server discovery (the "Search my network" sweep).

import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiru/src/features/onboarding/data/server_discovery.dart';

void main() {
  group('subnetHosts', () {
    test('generates the /24 sweep including the ip, de-duped', () {
      final hosts = subnetHosts('192.168.1.50');
      expect(hosts, contains('192.168.1.1'));
      expect(hosts, contains('192.168.1.254'));
      expect(hosts.first, '192.168.1.50'); // ip probed first
      expect(hosts.where((h) => h == '192.168.1.50').length, 1); // de-duped
      expect(hosts.length, 254);
    });

    test('malformed ip → just itself', () {
      expect(subnetHosts('not-an-ip'), ['not-an-ip']);
    });
  });

  group('discoverServerOnLan', () {
    test('returns http://<ip>:4567 for the first responder on :4567', () async {
      final found = await discoverServerOnLan(
        wifiIp: () async => '192.168.1.50',
        ping: (host, port) async => host == '192.168.1.7' && port == 4567,
      );
      expect(found, 'http://192.168.1.7:4567');
    });

    test('no Wi-Fi IP → null', () async {
      expect(await discoverServerOnLan(wifiIp: () async => null), isNull);
    });

    test('nothing responds → null', () async {
      final found = await discoverServerOnLan(
        wifiIp: () async => '192.168.1.50',
        ping: (_, __) async => false,
      );
      expect(found, isNull);
    });
  });
}
