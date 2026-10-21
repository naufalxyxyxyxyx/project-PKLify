import 'package:flutter_test/flutter_test.dart';
import 'package:pklify/main.dart';
import 'package:pklify/api.dart';

void main() {
  testWidgets('login lokal tidak menampilkan kotak dan password demo', (
    tester,
  ) async {
    Api.localMode = true;
    addTearDown(() => Api.localMode = false);
    await tester.pumpWidget(const PklifyApp());
    expect(find.textContaining('Mode demo lokal'), findsNothing);
    expect(find.textContaining('SiswaPkl!2026'), findsNothing);
    expect(find.textContaining('GuruPkl!2026'), findsNothing);
    expect(find.text('Masuk ke PKLify'), findsOneWidget);
  });
  testWidgets('menampilkan halaman login PKLify', (tester) async {
    await tester.pumpWidget(const PklifyApp());
    expect(find.text('PKLify'), findsOneWidget);
    expect(find.text('Masuk ke PKLify'), findsOneWidget);
  });
}
