import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../state/android_core.dart';
import '../jar/jar_manager.dart';
import '../../utils/logger.dart';

/// TCP server for JAR (Logic Engine) connections
class JarServer {
  JarServer._internal();
  static final JarServer _instance = JarServer._internal();
  factory JarServer() => _instance;

  final _log = AppLogger('JarServer');
  final _core = AndroidCore();
  final _jarManager = JarManager();

  ServerSocket? _server;
  static const int _port = 8080;
  final _clients = <Socket>[];

  /// Starts the TCP server
  Future<void> start() async {
    if (_server != null) return;
    
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _server!.listen(_onClientConnected);
      _log.info('JAR TCP server listening on port $_port');
    } catch (e) {
      _log.error('Failed to start JAR server: $e');
      rethrow;
    }
  }

  void _onClientConnected(Socket socket) {
    _log.info('JAR client connected: ${socket.remoteAddress}:${socket.remotePort}');
    _clients.add(socket);
    
    socket.setOption(SocketOption.tcpNoDelay, true);
    
    socket.listen(
      (data) => _onData(socket, data),
      onError: (error) => _onError(socket, error),
      onDone: () => _onDisconnect(socket),
      cancelOnError: false,
    );
  }

  void _onData(Socket socket, List<int> data) {
    try {
      final message = utf8.decode(data).trim();
      if (message.isEmpty) return;
      
      _log.debug('JAR received: $message');
      
      // Parse JSON message
      final json = jsonDecode(message);
      if (json is Map<String, dynamic>) {
        final type = json['type'] as String?;
        
        if (type == 'jar.hello') {
          _log.info('JAR handshake received');
          _core.setJarConnected(true);
          _jarManager.markHandshakeComplete();
        } else {
          // Forward other messages to core
          _core.updateFromMessage(json);
        }
      }
    } catch (e) {
      _log.warning('Failed to parse JAR message: $e');
    }
  }

  void _onError(Socket socket, Object error) {
    _log.warning('JAR socket error: $error');
    _removeClient(socket);
  }

  void _onDisconnect(Socket socket) {
    _log.info('JAR client disconnected: ${socket.remoteAddress}:${socket.remotePort}');
    _removeClient(socket);
    _core.setJarConnected(false);
  }

  void _removeClient(Socket socket) {
    _clients.remove(socket);
    socket.destroy();
  }

  /// Sends a message to all connected JAR clients
  void broadcast(Map<String, dynamic> message) {
    final data = '${jsonEncode(message)}\n';
    for (final client in _clients) {
      try {
        client.add(utf8.encode(data));
      } catch (e) {
        _log.warning('Failed to send to JAR client: $e');
      }
    }
  }

  void stop() {
    _server?.close();
    _server = null;
    for (final client in _clients) {
      client.destroy();
    }
    _clients.clear();
    _core.setJarConnected(false);
    _log.info('JAR server stopped');
  }
}