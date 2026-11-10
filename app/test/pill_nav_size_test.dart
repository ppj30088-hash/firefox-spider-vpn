import 'package:arman_vpn/ui/pill_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The phone bar once grew as tall as the screen (the label's Align took
// the whole height its parent offered) and then overflowed sideways on
// narrow phones (the circles were too big for the names). This test
// keeps the bar short, at the bottom, and fitting at phone widths.
void main() {
  const english = [
    (Icon(Icons.home_outlined), Icon(Icons.home_rounded), 'Home'),
    (Icon(Icons.public_outlined), Icon(Icons.public_rounded), 'Servers'),
    (Icon(Icons.people_outline_rounded), Icon(Icons.people_rounded), 'Accounts'),
    (Icon(Icons.settings_outlined), Icon(Icons.settings_rounded), 'Settings'),
    (Icon(Icons.receipt_long_outlined), Icon(Icons.receipt_long_rounded), 'Logs'),
  ];
  const persian = [
    (Icon(Icons.home_outlined), Icon(Icons.home_rounded), 'خانه'),
    (Icon(Icons.public_outlined), Icon(Icons.public_rounded), 'سرورها'),
    (Icon(Icons.people_outline_rounded), Icon(Icons.people_rounded), 'اکانت‌ها'),
    (Icon(Icons.settings_outlined), Icon(Icons.settings_rounded), 'تنظیمات'),
    (Icon(Icons.receipt_long_outlined), Icon(Icons.receipt_long_rounded), 'لاگ‌ها'),
  ];

  testWidgets('the phone pill bar stays short and at the bottom', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: PillNavBar(
                  items: persian,
                  selected: 0,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.getSize(find.byType(PillNavBar));
    expect(bar.height, lessThan(100));
    expect(bar.height, greaterThan(30));
    // The bar sits at the bottom, above its 10px bottom padding.
    final barTopLeft = tester.getTopLeft(find.byType(PillNavBar));
    expect(barTopLeft.dy + bar.height, closeTo(790, 1));

    final pills = find.descendant(
      of: find.byType(PillNavBar),
      matching: find.byType(Material),
    );
    for (var i = 0; i < pills.evaluate().length; i++) {
      expect(tester.getSize(pills.at(i)).height, lessThan(100));
    }
  });

  testWidgets('the phone pill bar fits at narrow widths', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [400.0, 360.0, 320.0]) {
      for (final (labels, rtl) in [(english, false), (persian, true)]) {
        for (var selected = 0; selected < 5; selected++) {
          tester.view.physicalSize = Size(width, 860);
          tester.view.devicePixelRatio = 1.0;
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Scaffold(
                  body: const SizedBox(),
                  bottomNavigationBar: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: PillNavBar(
                        items: labels,
                        selected: selected,
                        onSelected: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Any overflow throws during layout and fails the test.
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(PillNavBar)).height,
            lessThan(100),
          );
        }
      }
    }
  });
}
