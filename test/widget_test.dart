import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_sheet/app.dart';
import 'package:tracker_sheet/services/notification_service.dart';

/// A phone-sized render check: every RenderFlex overflow is reported as an
/// exception, so a clean run means the layout fits that width.
void main() {
  // The Supabase config is compiled in (see lib/config/supabase_config.dart),
  // so the service really does reach for the client as soon as a user is
  // signed in - the test has to provide one.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'https://layout-test.supabase.co', anonKey: 'test-anon-key');
  });

  Future<void> pumpAt(WidgetTester tester, Size css) async {
    tester.view.physicalSize = Size(css.width * 3, css.height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      NotificationService.instance.dispose();
    });
    // Signed in so the home screen (with the weekly toolbar) actually renders.
    SharedPreferences.setMockInitialValues({'tracker_email': 'layout@test.dev', 'tracker_user_id': 'layout-user'});
    await tester.pumpWidget(const ProviderScope(child: TrackerApp()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    // Stop our own timers, tear the app tree down (which unsubscribes realtime
    // and schedules a 50s disconnect timer), then flush it - otherwise the test
    // fails on "pending timers" before it can report a layout error.
    NotificationService.instance.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 60));
  }

  for (final size in const [Size(360, 780), Size(390, 844), Size(412, 915)]) {
    testWidgets('home screen has no overflow at ${size.width.toInt()}px', (tester) async {
      await pumpAt(tester, size);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('App loads', (tester) async {
    tester.view.physicalSize = const Size(5200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const ProviderScope(child: TrackerApp()));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(seconds: 1));
    // App should show either loading, name entry, or tracker sheet — all contain MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
    NotificationService.instance.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 60));
  });
}
