import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../state/android_core.dart';
import '../apk/apk_manager.dart';
import '../../utils/logger.dart';

/// WebSocket server for APK (Feature Hub) connections
class ApkServer {
  ApkServer._internal();
  static final ApkServer _instance = ApkServer._internal();
  factory ApkServer() => _instance;

  final _log = AppLogger('ApkServer');
  final _core = AndroidCore();
  final _apkManager = ApkManager();

  HttpServer? _server;
  static const int _port = 8081;
  final _channels = <WebSocketChannel>[];

  /// Starts the WebSocket server
  Future<void> start() async {
    if (_server != null) return;

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _server!.listen(_onHttpRequest);
      _log.info('APK WebSocket server listening on port $_port');
    } catch (e) {
      _log.error('Failed to start APK server: $e');
      rethrow;
    }
  }

  void _onHttpRequest(HttpRequest request) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then(_onWebSocketConnected);
    } else {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('WebSocket upgrade required')
        ..close();
    }
  }

  void _onWebSocketConnected(WebSocketChannel channel) {
    _log.info('APK WebSocket connected');
    _channels.add(channel);
    
    // Notify APK manager of new connection
    _apkManager.handleConnection(channel);
    
    channel.stream.listen(
      (message) => _onMessage(channel, message),
      onError: (error) => _onError(channel, error),
      onDone: () => _onDisconnect(channel),
      cancelOnError: false,
    );
  }

  void _onMessage(WebSocketChannel channel, dynamic message) {
    try {
      final text = message.toString().trim();
      if (text.isEmpty) return;
      
      _log.debug('APK received: $text');
      
      final json = jsonDecode(text);
      if (json is Map<String, dynamic>) {
        final type = json['type'] as String?;
        
        if (type == 'apk.hello') {
          _log.info('APK handshake received');
          _core.setApkConnected(true);
          _apkManager.handshakeCompleter.complete();
        } else {
          // Forward other messages to core
          _core.updateFromMessage(json);
        }
      }
    } catch (e) {
      _log.warning('Failed to parse APK message: $e');
    }
  }

  void _onError(WebSocketChannel channel, Object error) {
    _log.warning('APK WebSocket error: $error');
    _removeChannel(channel);
  }

  void _onDisconnect(WebSocketChannel channel) {
    _log.info('APK WebSocket disconnected');
    _removeChannel(channel);
    _core.setApkConnected(false);
  }

  void _removeChannel(WebSocketChannel channel) {
    _channels.remove(channel);
    channel.sink.close();
  }

  /// Broadcasts a message to all connected APK clients
  void broadcast(Map<String, dynamic> message) {
    final data = jsonEncode(message);
    for (final channel in _channels) {
      try {
        channel.sink.add(data);
      } catch (e) {
        _log.warning('Failed to send to APK channel: $e');
      }
    }
  }

  void stop() {
    _server?.close();
    _server = null;
    for (final channel in _channels) {
      channel.sink.close();
    }
    _channels.clear();
    _core.setApkConnected(false);
    _log.info('APK server stopped');
  }
}