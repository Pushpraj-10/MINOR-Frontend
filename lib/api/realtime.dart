import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'endpoints.dart';

class RealtimeService {
  RealtimeService._internal();
  static final RealtimeService I = RealtimeService._internal();

  IO.Socket? _socket;

  // Connect (or reuse existing) socket to /sessions namespace
  IO.Socket _ensureConnected() {
    if (_socket != null && _socket!.connected) return _socket!;

    // Derive ws origin from ApiConfig.baseUrl by stripping "/api"
    // Expecting baseUrl like https://host/api
    String base = ApiConfig.baseUrl;
    final idx = base.indexOf('/api');
    final origin = idx > 0 ? base.substring(0, idx) : base;

    // Use websocket transport to avoid long polling issues
    final socket = IO.io(
      '$origin/sessions',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableForceNewConnection()
          .disableAutoConnect() // we'll connect explicitly
          .build(),
    );

    socket.on('connect', (_) {
      // print('Socket connected');
    });
    socket.on('disconnect', (_) {
      // print('Socket disconnected');
    });
    socket.on('connect_error', (err) {
      // print('Socket connect_error: $err');
    });

    socket.connect();
    _socket = socket;
    return socket;
  }

  Stream<QrTick> subscribeQrTicks(String sessionId, {bool asProfessor = true}) {
    final socket = _ensureConnected();
    final controller = StreamController<QrTick>(onCancel: () {
      // no-op, keep socket for reuse
    });

    // Using sessionId as room name on server; no local usage needed

    void onTick(dynamic payload) {
      try {
        final map = (payload is Map)
            ? payload as Map<String, dynamic>
            : json.decode(payload as String) as Map<String, dynamic>;
        final sid = map['sessionId'] as String? ?? '';
        final token = map['token'] as String? ?? '';
        final ts = (map['ts'] is int)
            ? map['ts'] as int
            : int.tryParse(map['ts']?.toString() ?? '') ?? 0;
        if (sid == sessionId && token.isNotEmpty) {
          controller.add(QrTick(sessionId: sid, token: token, ts: ts));
        }
      } catch (_) {}
    }

    // Join and start listening
    if (asProfessor) {
      socket.emit('professor:join', {'sessionId': sessionId});
    } else {
      socket.emit('student:subscribe', {'sessionId': sessionId});
    }

    socket.on('qr:tick', onTick);

    controller.onCancel = () {
      socket.off('qr:tick', onTick);
    };

    return controller.stream;
  }
}

class QrTick {
  final String sessionId;
  final String token;
  final int ts;

  QrTick({required this.sessionId, required this.token, required this.ts});

  // Produce compact QR payload: "{sessionId}:{token}"
  String toQrString() => '$sessionId:$token';
}
