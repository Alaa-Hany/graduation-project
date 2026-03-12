import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/models/admin_user.dart';
import 'package:kinder_world/features/admin/auth/admin_auth_provider.dart';
import 'package:kinder_world/features/admin/dashboard/admin_home_tab.dart';

void main() {
  testWidgets('admin home tab renders overview content',
      (WidgetTester tester) async {
    const admin = AdminUser(
      id: 1,
      email: 'admin@kinderworld.app',
      name: 'Super Admin',
      isActive: true,
      roles: ['super_admin'],
      permissions: [
        'admin.users.view',
        'admin.children.view',
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAdminProvider.overrideWithValue(admin),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [
            Locale('en'),
            Locale('ar'),
          ],
          home: Scaffold(
            body: AdminHomeTab(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Your permissions'), findsOneWidget);
  });
}
