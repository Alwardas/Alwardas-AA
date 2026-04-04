import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/theme_provider.dart';

void main() {
  testWidgets('LoginScreen loads properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify elements are present
    expect(find.text('Login ID'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    
    // Verify buttons
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
