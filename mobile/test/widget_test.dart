import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App pumps inside ProviderScope', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump();
    expect(find.byType(App), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);

    // Splash schedules delays; replace the tree so they complete unmounted.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
