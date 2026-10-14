import 'package:flutter_test/flutter_test.dart';
import 'package:pklify/main.dart';

void main() {
  testWidgets('menampilkan halaman login PKLify', (tester) async {
    await tester.pumpWidget(const PklifyApp());
    expect(find.text('PKLify'), findsOneWidget);
    expect(find.text('Masuk ke PKLify'), findsOneWidget);
  });
}
