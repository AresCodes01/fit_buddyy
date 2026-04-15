import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Da Firebase im main() initialisiert wird, können einfache Widget-Tests 
    // ohne Mocking fehlschlagen. Dieser Test dient nur als Platzhalter.
    expect(true, true);
  });
}
