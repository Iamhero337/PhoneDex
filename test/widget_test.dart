import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phonedex/src/state/android_core.dart';
import 'package:phonedex/src/ui/about_screen.dart';

void main() {
  test('AndroidCore initial state test', () {
    final core = AndroidCore.instance;
    expect(core.jarConnected.value, isFalse);
    expect(core.apkConnected.value, isFalse);
    expect(core.allConnected.value, isFalse);
  });

  testWidgets('AboutScreen renders title test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AboutScreen(),
      ),
    );
    expect(find.text('About PhoneDex'), findsOneWidget);
    expect(find.text('PhoneDex'), findsWidgets);
  });
}
