import 'package:firefox_vpn/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the month\'s traffic is counted from the core\'s counter', () {
    final s = AppSettings();
    final oct = DateTime(2026, 10, 30);
    s.countTraffic(1000, now: oct);
    expect(s.usageBytes, 1000);
    // The counter grows: only the new bytes are added.
    s.countTraffic(1500, now: oct);
    expect(s.usageBytes, 1500);
    // The core restarted (a smaller counter): all of it is new.
    s.countTraffic(200, now: oct);
    expect(s.usageBytes, 1700);
    // The same counter again adds nothing.
    s.countTraffic(200, now: oct);
    expect(s.usageBytes, 1700);
    // A new month starts again from zero.
    s.countTraffic(300, now: DateTime(2026, 11, 1));
    expect(s.usageMonth, '2026-11');
    expect(s.usageBytes, 100);
  });
}
