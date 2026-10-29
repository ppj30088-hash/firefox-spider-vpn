import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// What the window's close button does.
enum CloseAction { ask, tray, quit }

/// The app's own preferences (language, theme, close button), kept in
/// `app-settings.json` in the data folder beside the core's files. The VPN
/// settings belong to the core.
class AppSettings extends ChangeNotifier {
  AppSettings({this.file});

  final File? file;

  /// A language code (`en`, `fa`, `zh`, `ru`), or empty for the system
  /// language.
  String language = '';
  ThemeMode themeMode = ThemeMode.system;
  CloseAction closeAction = CloseAction.ask;

  /// True until the user finished the welcome page.
  bool firstRun = false;

  /// Shows the public IP (the address websites see). Off by default: the
  /// location is shown by its country either way.
  bool showPublicIp = false;

  /// When the user closed the "account running out" notice; it stays away
  /// for a day after.
  DateTime? lowQuotaDismissedAt;

  /// The newer version whose notice the user closed; a later one shows.
  String dismissedUpdate = '';

  /// The last successful look for a newer version, and the newer version it
  /// found ("" for none) with its page, so the notice outlasts a restart.
  DateTime? updateCheckedAt;
  String updateVersion = '';
  String updateUrl = '';

  /// Downloads a newer version in the background and installs it the next
  /// time the app starts (the Windows app, which updates itself); on unless
  /// the user turned it off.
  bool autoUpdate = true;

  /// Starts the app in the tray when the user signs in to Windows; on
  /// unless the user turned it off.
  bool autostart = true;

  /// Connects by itself when started with the computer ([autostart]); off
  /// until the user turns it on. The core decides how (Daemon.AutoConnect).
  bool autoConnect = false;

  /// The home page's card when TUN mode refused a program's call or game
  /// (UDP); on unless the user turned it off.
  bool udpNotice = true;

  /// The traffic through the VPN this month, counted by this app from the
  /// core's own counter (see [countTraffic]): what the home page's usage
  /// card shows when the account does not say how much it used. Starts at
  /// zero each month. [usageMonth] is that month, "2026-10".
  String usageMonth = '';
  int usageBytes = 0;
  int _usageLastTotal = 0;
  DateTime? _usageSavedAt;

  /// The monthly allowance the usage card counts against when the account
  /// has none to show: 50 GB (as the app writes sizes, 1 GB = 1024 MB).
  static const usageLimitBytes = 50 * 1024 * 1024 * 1024;

  /// The columns the Logs page's Connections tab hides (ConnectionsView):
  /// at first all but the time, the destination, the rule, and the
  /// protocol. Kept in this file.
  Set<String> hiddenConnectionColumns = {'inbound', 'traffic', 'duration'};

  /// The app's languages, in the order the language menus list them.
  /// 'zh' is Simplified and 'zh_Hant' Traditional Chinese.
  static const supportedLanguages = [
    'en',
    'fa',
    'zh',
    'zh_Hant',
    'ru',
    'tr',
    'ar',
    // The rest by their own names.
    'az',
    'id',
    'es',
    'fr',
    'hu',
    'pt',
    'vi',
    'bn',
  ];

  /// Languages written right to left.
  static const rtlLanguages = {'fa', 'ar'};

  /// The locale of a language code such as 'fa' or 'zh_Hant'.
  static Locale localeOf(String language) {
    final parts = language.split('_');
    return parts.length == 2
        ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1])
        : Locale(language);
  }

  /// The app language for the system's [locale]: Traditional Chinese for
  /// the Hant script or Taiwan, Hong Kong, and Macau; else the language
  /// when the app has it; else English.
  static String languageFor(Locale locale) {
    if (locale.languageCode == 'zh') {
      final traditional =
          locale.scriptCode == 'Hant' ||
          const {'TW', 'HK', 'MO'}.contains(locale.countryCode);
      return traditional ? 'zh_Hant' : 'zh';
    }
    return supportedLanguages.contains(locale.languageCode)
        ? locale.languageCode
        : 'en';
  }

  /// The app language for the system's preferred [locales], in order: the
  /// first one the app has; else English (not Flutter's default, the first
  /// language it was built with).
  static String languageForList(List<Locale>? locales) {
    for (final locale in locales ?? const <Locale>[]) {
      if (locale.languageCode == 'zh' ||
          supportedLanguages.contains(locale.languageCode)) {
        return languageFor(locale);
      }
    }
    return 'en';
  }

  /// The core's routing regions (`routing.region`); empty is none.
  static const regions = ['ir', 'cn', 'ru', 'af', 'tr', 'id', 'br', ''];

  Locale? get locale => language.isEmpty ? null : localeOf(language);

  /// The routing region most users of [language] want: Persian is Iran,
  /// Chinese China, Russian Russia; null when a language says nothing.
  static String? regionForLanguage(String language) => switch (language) {
    'fa' => 'ir',
    'zh' => 'cn',
    'ru' => 'ru',
    'id' => 'id',
    'tr' => 'tr',
    'pt' => 'br',
    _ => null,
  };

  /// The region to offer first: from [language], else from the system's
  /// country ([countryCode], such as IR), else none.
  static String suggestedRegion(String language, String? countryCode) {
    final byLanguage = regionForLanguage(language);
    if (byLanguage != null) return byLanguage;
    final country = (countryCode ?? '').toLowerCase();
    return regions.contains(country) ? country : '';
  }

  static Future<AppSettings> load(String dataDir) async {
    final s = AppSettings(
      file: File('$dataDir${Platform.pathSeparator}app-settings.json'),
    );
    try {
      final j = jsonDecode(await s.file!.readAsString());
      if (j is Map<String, Object?>) {
        if (j['language'] case final String l
            when supportedLanguages.contains(l)) {
          s.language = l;
        }
        s.themeMode =
            ThemeMode.values.asNameMap()[j['theme']] ?? ThemeMode.system;
        s.closeAction =
            CloseAction.values.asNameMap()[j['close']] ?? CloseAction.ask;
        s.firstRun = j['welcome_done'] != true;
        s.showPublicIp = j['show_public_ip'] == true;
        if (j['dismissed_update'] case final String v) s.dismissedUpdate = v;
        if (j['update_version'] case final String v) s.updateVersion = v;
        if (j['update_url'] case final String v) s.updateUrl = v;
        s.updateCheckedAt = switch (j['update_checked_at']) {
          final String t => DateTime.tryParse(t),
          _ => null,
        };
        s.lowQuotaDismissedAt = switch (j['low_quota_dismissed_at']) {
          final String t => DateTime.tryParse(t),
          _ => null,
        };
        s.autostart = j['autostart'] != false;
        s.autoConnect = j['auto_connect'] == true;
        s.autoUpdate = j['auto_update'] != false;
        s.udpNotice = j['udp_notice'] != false;
        if (j['usage_month'] case final String v) s.usageMonth = v;
        if (j['usage_bytes'] case final int v) s.usageBytes = v;
        if (j['usage_last_total'] case final int v) s._usageLastTotal = v;
        if (j['hidden_connection_columns'] case final List<Object?> v) {
          s.hiddenConnectionColumns = {...v.whereType<String>()};
        }
      }
    } on FileSystemException {
      // First run: defaults, and the welcome page.
      s.firstRun = true;
    } on FormatException {
      // A broken file: defaults, rewritten on the next change.
    }
    return s;
  }

  void update({
    String? language,
    ThemeMode? themeMode,
    CloseAction? closeAction,
    bool? firstRun,
    bool? showPublicIp,
    DateTime? lowQuotaDismissedAt,
    String? dismissedUpdate,
    DateTime? updateCheckedAt,
    String? updateVersion,
    String? updateUrl,
    bool? autostart,
    bool? autoConnect,
    bool? autoUpdate,
    bool? udpNotice,
    Set<String>? hiddenConnectionColumns,
  }) {
    this.hiddenConnectionColumns =
        hiddenConnectionColumns ?? this.hiddenConnectionColumns;
    this.udpNotice = udpNotice ?? this.udpNotice;
    this.autoUpdate = autoUpdate ?? this.autoUpdate;
    this.autostart = autostart ?? this.autostart;
    this.autoConnect = autoConnect ?? this.autoConnect;
    this.showPublicIp = showPublicIp ?? this.showPublicIp;
    this.lowQuotaDismissedAt = lowQuotaDismissedAt ?? this.lowQuotaDismissedAt;
    this.dismissedUpdate = dismissedUpdate ?? this.dismissedUpdate;
    this.updateCheckedAt = updateCheckedAt ?? this.updateCheckedAt;
    this.updateVersion = updateVersion ?? this.updateVersion;
    this.updateUrl = updateUrl ?? this.updateUrl;
    this.firstRun = firstRun ?? this.firstRun;
    this.language = language ?? this.language;
    this.themeMode = themeMode ?? this.themeMode;
    this.closeAction = closeAction ?? this.closeAction;
    notifyListeners();
    _save();
  }

  /// Adds the traffic since the last call to this month's count. [total] is
  /// the core's own counter, which grows from zero each time the core starts
  /// (a smaller one means a restart: all of it is new). The count is kept in
  /// the file at most every 15 seconds, not on every status.
  void countTraffic(int total, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final month = '${t.year}-${t.month.toString().padLeft(2, '0')}';
    var changed = false;
    if (usageMonth != month) {
      usageMonth = month;
      usageBytes = 0;
      changed = true;
    }
    final fresh = total >= _usageLastTotal ? total - _usageLastTotal : total;
    if (fresh > 0) {
      usageBytes += fresh;
      changed = true;
    }
    if (total != _usageLastTotal) {
      _usageLastTotal = total;
      changed = true;
    }
    final saved = _usageSavedAt;
    if (changed &&
        (saved == null || t.difference(saved) > const Duration(seconds: 15))) {
      _usageSavedAt = t;
      _save();
    }
  }

  Future<void> _save() async {
    final f = file;
    if (f == null) return;
    try {
      await f.parent.create(recursive: true);
      await f.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'language': language,
          'theme': themeMode.name,
          'close': closeAction.name,
          'welcome_done': !firstRun,
          'show_public_ip': showPublicIp,
          'low_quota_dismissed_at': lowQuotaDismissedAt?.toIso8601String(),
          'dismissed_update': dismissedUpdate,
          'update_checked_at': updateCheckedAt?.toIso8601String(),
          'update_version': updateVersion,
          'update_url': updateUrl,
          'autostart': autostart,
          'auto_connect': autoConnect,
          'auto_update': autoUpdate,
          'udp_notice': udpNotice,
          'usage_month': usageMonth,
          'usage_bytes': usageBytes,
          'usage_last_total': _usageLastTotal,
          'hidden_connection_columns': hiddenConnectionColumns.toList(),
        }),
      );
    } on FileSystemException {
      // Not fatal: the choice holds until the app quits.
    }
  }
}
