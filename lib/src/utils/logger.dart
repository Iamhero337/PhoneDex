import 'dart:io';

class AppLogger {
  final String tag;
  const AppLogger(this.tag);

  void debug(String m) => _log('DEBUG', m);
  void info(String m) => _log('INFO', m);
  void warning(String m) => _log('WARN', m);
  void error(String m, [Object? e, StackTrace? s]) {
    _log('ERROR', m);
    if (e != null) stderr.writeln('[ERROR] $e');
    if (s != null) stderr.writeln('[STACK] $s');
  }

  void _log(String level, String msg) {
    final t = DateTime.now().toIso8601String().substring(11, 23);
    print('[$t] [$tag] [$level] $msg');
  }
}