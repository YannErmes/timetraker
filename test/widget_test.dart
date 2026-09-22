import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_sheet/app.dart';

void main() {
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
  });
}
