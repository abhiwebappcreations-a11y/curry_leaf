import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CounterDiscoveryService {
  static const int discoveryPort = 41234;

  /// Listens and broadcasts probes to auto-detect Counter POS on the same Wi-Fi
  static Future<Map<String, dynamic>?> discoverCounterPos({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    // When running inside a web browser preview on Counter PC, fallback to localhost
    if (kIsWeb) {
      return {
        'host': '127.0.0.1',
        'port': 4000,
        'restaurantName': 'Curry Leaf Fine Dining',
      };
    }

    final completer = Completer<Map<String, dynamic>?>();
    RawDatagramSocket? socket;
    Timer? probeTimer;
    Timer? timeoutTimer;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      // Listen for UDP replies or beacons
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null && !completer.isCompleted) {
            try {
              final text = utf8.decode(datagram.data);
              final json = jsonDecode(text);
              if (json is Map<String, dynamic> &&
                  json['service'] == 'hinopt_counter_pos' &&
                  json['host'] != null) {
                completer.complete(json);
              }
            } catch (_) {}
          }
        }
      });

      // Broadcast probe to 255.255.255.255:41234
      void sendProbe() {
        if (socket == null || completer.isCompleted) return;
        try {
          final payload = utf8.encode(jsonEncode({'action': 'discover', 'query': 'find_hinopt_pos'}));
          socket.send(payload, InternetAddress('255.255.255.255'), discoveryPort);
        } catch (_) {}
      }

      sendProbe();
      probeTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => sendProbe());

      // Timeout fallback
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      Map<String, dynamic>? result = await completer.future;

      // If UDP broadcast yielded no result, fall back to intelligent LAN HTTP subnet scan
      if (result == null) {
        final scannedIp = await scanSubnetForCounterPos();
        if (scannedIp != null) {
          result = {
            'host': scannedIp,
            'port': 4000,
            'restaurantName': 'Hinopt Counter POS',
          };
        }
      }

      if (result != null && result['host'] != null) {
        final host = result['host'].toString();
        final port = int.tryParse(result['port'].toString()) ?? 4000;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('counter_pc_host', host);
        await prefs.setInt('counter_pc_port', port);
      }

      return result;
    } catch (_) {
      // Direct subnet scan fallback on exception
      final scannedIp = await scanSubnetForCounterPos();
      if (scannedIp != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('counter_pc_host', scannedIp);
        await prefs.setInt('counter_pc_port', 4000);
        return {
          'host': scannedIp,
          'port': 4000,
          'restaurantName': 'Hinopt Counter POS',
        };
      }
      return null;
    } finally {
      probeTimer?.cancel();
      timeoutTimer?.cancel();
      socket?.close();
    }
  }

  /// Fast HTTP subnet scanner for Counter POS API across priority and local subnet IPs
  static Future<String?> scanSubnetForCounterPos({int port = 4000}) async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      String? subnetPrefix;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
              break;
            }
          }
        }
        if (subnetPrefix != null) break;
      }

      final prefixesToCheck = <String>[];
      if (subnetPrefix != null) prefixesToCheck.add(subnetPrefix);
      for (final p in ['192.168.10', '192.168.1', '192.168.0', '192.168.29']) {
        if (!prefixesToCheck.contains(p)) prefixesToCheck.add(p);
      }

      for (final prefix in prefixesToCheck) {
        // High-probability host numbers (including current .4 and common .100, .1)
        final priorityHosts = [5, 4, 1, 2, 3, 100, 101, 10, 20, 50, 150];
        for (final h in priorityHosts) {
          final ip = '$prefix.$h';
          if (await _pingHealth(ip, port)) {
            return ip;
          }
        }
      }

      // Deeper sweep on the primary local subnet
      if (subnetPrefix != null) {
        final allHosts = List.generate(254, (i) => i + 1);
        for (var i = 0; i < allHosts.length; i += 25) {
          final chunk = allHosts.sublist(i, (i + 25 > allHosts.length) ? allHosts.length : i + 25);
          final futures = chunk.map((h) => _pingHealth('$subnetPrefix.$h', port));
          final results = await Future.wait(futures);
          for (var j = 0; j < results.length; j++) {
            if (results[j]) {
              return '$subnetPrefix.${chunk[j]}';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> _pingHealth(String host, int port) async {
    final client = http.Client();
    try {
      final resp = await client
          .get(Uri.parse('http://$host:$port/api/health'))
          .timeout(const Duration(milliseconds: 350));
      if (resp.statusCode == 200 && resp.body.contains('hinopt-local-api')) {
        return true;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return false;
  }
}
