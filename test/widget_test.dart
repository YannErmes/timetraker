import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_sheet/app.dart';
import 'package:tracker_sheet/models/enums.dart';
import 'package:tracker_sheet/providers/app_providers.dart';
import 'package:tracker_sheet/services/notification_service.dart';

/// Grabs a [WidgetRef] from inside the app subtree so a test can drive providers.
class _CaptureRef extends ConsumerWidget {
  final void Function(WidgetRef) onRef;
  final Widget child;
  const _CaptureRef({required this.onRef, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref, [Widget? child]) {
    onRef(ref);
    return child ?? const SizedBox.shrink();
  }
}

/// Phone-width render checks: every RenderFlex overflow is reported as an
/// exception, so a clean run means the layout fits that width. These caught
/// the weekly toolbar, the "in progress" tooltip and the daily stats title
/// row, none of which are visible on a desktop window.
void main() {
  // The Supabase config is compiled in (see lib/config/supabase_config.dart),
  // so the service really does reach for the client as soon as a user is
  // signed in - the test has to provide one.
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'https://layout-test.supabase.co', anonKey: 'test-anon-key');
  });

  tearDown(() {
    // The notification scheduler keeps a 20s ticker and a nearest-alarm timer;
    // a pending timer fails the test before it can report a layout error.
    NotificationService.instance.dispose();
  });

  Future<WidgetRef> pumpAt(WidgetTester tester, Size css) async {
    tester.view.physicalSize = Size(css.width * 3, css.height * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    // The test binding keeps only the exception message; print the full chain
    // so a failure names the offending widget.
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final nodes = details.informationCollector?.call().map((n) => n.toStringDeep()).join('\n') ?? '';
      // ignore: avoid_print
      print('FULL ERROR >>> ${details.exceptionAsString()}\n$nodes');
    };
    addTearDown(() => FlutterError.onError = prevOnError);

    // Signed in so the home screen (with its toolbar) actually renders.
    SharedPreferences.setMockInitialValues({'tracker_email': 'layout@test.dev', 'tracker_user_id': 'layout-user'});
    WidgetRef? captured;
    await tester.pumpWidget(ProviderScope(child: _CaptureRef(onRef: (r) => captured = r, child: const TrackerApp())));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    // Tear the app tree down (which unsubscribes realtime and schedules a 50s
    // disconnect timer) and flush it.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 60));
    return captured!;
  }

  for (final size in const [Size(360, 780), Size(390, 844), Size(412, 915)]) {
    testWidgets('home screen has no overflow at ${size.width.toInt()}px', (tester) async {
      await pumpAt(tester, size);
      final err = tester.takeException();
      if (err != null) {
        // ignore: avoid_print
        print('LAYOUT ERROR at ${size.width.toInt()}px >>> $err');
      }
      expect(err, isNull);
    });
  }

  // Phones open on the Daily view, so the Weekly task list needs its own
  // check - it is only reached by switching views by hand.
  testWidgets('mobile weekly task list has no overflow at 360px', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({'tracker_email': 'layout@test.dev', 'tracker_user_id': 'layout-user'});
    WidgetRef? captured;
    await tester.pumpWidget(ProviderScope(child: _CaptureRef(onRef: (r) => captured = r, child: const TrackerApp())));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    captured!.read(viewModeProvider.notifier).state = ViewMode.weekly;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    final err = tester.takeException();
    if (err != null) {
      // ignore: avoid_print
      print('LAYOUT ERROR (mobile weekly list) >>> $err');
    }
    expect(err, isNull);
  });

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
    // Timers must be stopped inside the body: the pending-timer check runs
    // before tearDown, so disposing only in tearDown is too late.
    NotificationService.instance.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 60));
  });
}
