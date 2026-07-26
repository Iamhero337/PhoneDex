import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:phonedex/src/state/android_core.dart';
import 'package:phonedex/src/apk/apk_manager.dart';
import 'package:phonedex/src/utils/logger.dart';

class ApkServer {
  ApkServer._();
  static final ApkServer _instance = ApkServer._();
  factory ApkServer() => _instance;

  final _log = AppLogger('ApkSrv');
  final _core = AndroidCore.instance;
  final _apkMgr = ApkManager();
  HttpServer? _server;

  Future<void> start() async {
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 8081);
    _server!.listen((req) {
      if (req.uri.path == '/ws' && req.method == 'GET') {
        WebSocketTransformer.upgrade(req).then((ws) {
          _log.info('APK WS connected');
          _apkMgr.handleConnection(ws);
        });
      } else {
        req.response.statusCode = 200;
        req.response.write('PhoneDex APK Server running');
        req.response.close();
      }
    });
    _log.info('APK server on :8081');
  }

  void stop() { _server?.close(); _server = null; _core.setApkConnected(false); }
}