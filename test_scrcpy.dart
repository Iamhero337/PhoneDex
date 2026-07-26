import 'dart:io';
void main() async {
  final candidates = [
    'scrcpy',
    '/usr/bin/scrcpy',
    '/usr/local/bin/scrcpy',
  ];
  for (final c in candidates) {
    try {
      final r = await Process.run(c, ['--version'], runInShell: true);
      print('Tested $c: exitCode=${r.exitCode}, stdout=${r.stdout.toString().substring(0, 15)}');
    } catch (e) {
      print('Tested $c: error=$e');
    }
  }
}
