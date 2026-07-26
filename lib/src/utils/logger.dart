import 'dart:io';

/// Simple application logger
class AppLogger {
  final String _tag;
  static LogLevel _level = LogLevel.debug;

  AppLogger(this._tag);

  static void init({LogLevel level = LogLevel.debug}) {
    _level = level;
  }

  void debug(String message) {
    if (_level.index <= LogLevel.debug.index) {
      _log('DEBUG', message);
    }
  }

  void info(String message) {
    if (_level.index <= LogLevel.info.index) {
      _log('INFO', message);
    }
  }

  void warning(String message) {
    if (_level.index <= LogLevel.warning.index) {
      _log('WARN', message);
    }
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (_level.index <= LogLevel.error.index) {
      _log('ERROR', message);
      if (error != null) {
        stderr.writeln('$_tag [ERROR] $error');
      }
      if (stackTrace != null) {
        stderr.writeln('$_tag [STACK] $stackTrace');
      }
    }
  }

  void _log(String level, String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    print('[$timestamp] [$_tag] [$level] $message');
  }
}

enum LogLevel { debug, info, warning, error }