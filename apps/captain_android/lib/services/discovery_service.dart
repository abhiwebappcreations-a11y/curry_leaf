import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

      final result = await completer.future;

      if (result != null && result['host'] != null) {
        final host = result['host'].toString();
        final port = int.tryParse(result['port'].toString()) ?? 4000;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('counter_pc_host', host);
        await prefs.setInt('counter_pc_port', port);
      }

      return result;
    } catch (_) {
      return null;
    } finally {
      probeTimer?.cancel();
      timeoutTimer?.cancel();
      socket?.close();
    }
  }
}
