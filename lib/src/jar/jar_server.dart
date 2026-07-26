import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:phonedex/src/state/android_core.dart';
import 'package:phonedex/src/jar/jar_manager.dart';
import 'package:phonedex/src/utils/logger.dart';

class JarServer {
  JarServer._();
  static final JarServer _instance = JarServer._();
  factory JarServer() => _instance;

  final _log = AppLogger('JarSrv');
  final _core = AndroidCore.instance;
  final _jarMgr = JarManager.instance;
  ServerSocket? _server;
  final _clients = <Socket>[];

  Future<void> start() async {
    if (_server != null) return;
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 8080);
    _server!.listen((s) {
      _log.info('Client connected: ${s.remoteAddress}');
      _clients.add(s);
      s.setOption(SocketOption.tcpNoDelay, true);
      
      utf8.decoder.bind(s).transform(const LineSplitter()).listen(
        (line) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) return;
          try {
            final json = jsonDecode(trimmed) as Map<String, dynamic>;
            if (json['type'] == 'jar.hello') {
              _log.info('JAR handshake received');
              _core.setJarConnected(true);
              _jarMgr.markHandshakeComplete();
            } else {
              _core.updateFromMessage(json);
            }
          } catch (e) {
            _log.warning('Parse error ($e) on line: $trimmed');
          }
        },
        onError: (e) => _remove(s),
        onDone: () {
          _remove(s);
          _core.setJarConnected(false);
        },
      );
    });
    _log.info('JAR server running on :8080');
  }

  void _remove(Socket s) {
    _clients.remove(s);
    try { s.destroy(); } catch (_) {}
  }
  
  void broadcast(Map<String, dynamic> m) {
    final d = '${jsonEncode(m)}\n';
    for (final c in _clients) {
      try { c.add(utf8.encode(d)); } catch (_) {}
    }
  }

  void stop() {
    _server?.close();
    _server = null;
    for (final c in _clients) {
      try { c.destroy(); } catch (_) {}
    }
    _clients.clear();
    _core.setJarConnected(false);
  }
}