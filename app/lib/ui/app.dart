import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_api.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'about_page.dart';
import 'announcement_panel.dart';
import 'accounts_page.dart';
import 'focus_ring.dart';
import 'format.dart';
import 'logs_page.dart';
import 'mobile_shell.dart';
import 'overview_page.dart';
import 'port_dialog.dart';
import 'servers_page.dart';
import 'settings_page.dart';
import 'welcome_page.dart';
import 'widgets.dart';

ThemeData _theme(Brightness brightness, Locale locale) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF5E6678),
    brightness: brightness,
  );
  final dark = brightness == Brightness.dark;
  // Bundled Inter for English, Vazirmatn for Persian and Arabic, and the
  // platform's typography for the remaining languages.
  final font = languageFont(locale.languageCode);
  final theme = ThemeData(
    colorScheme: scheme,
    fontFamily: font,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF111218)
        : const Color(0xFFF5F5FA),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF1A1B23) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
    ),
  );
  return theme.copyWith(
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? const Color(0xFF15161D) : const Color(0xFFECECF4),
      // NavigationRail replaces DefaultTextStyle, so retain the resolved
      // platform font instead of letting a null family choose a fallback.
      selectedLabelTextStyle: theme.textTheme.labelLarge!.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      unselectedLabelTextStyle: theme.textTheme.labelLarge!.copyWith(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      selectedIconTheme: IconThemeData(
        size: 24,
        color: scheme.onSecondaryContainer,
      ),
      unselectedIconTheme: IconThemeData(
        size: 24,
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}

class VpnApp extends StatelessWidget {
  const VpnApp({
    super.key,
    required this.core,
    required this.settings,
    this.navigatorKey,
  });

  final CoreController core;
  final AppSettings settings;
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (locales, _) =>
          AppSettings.localeOf(AppSettings.languageForList(locales)),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The theme depends on the resolved language for its font.
      builder: (context, child) {
        final locale = Localizations.localeOf(context);
        final dark = switch (settings.themeMode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        return Theme(
          data: _theme(dark ? Brightness.dark : Brightness.light, locale),
          // A clear ring around what a remote or the keyboard chose.
          child: FocusRing(
            atStart: Platform.isAndroid && AndroidCore.isTv,
            child: child!,
          ),
        );
      },
      home: Shell(core: core, settings: settings),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.core, required this.settings});

  final CoreController core;
  final AppSettings settings;

  @override
  State<Shell> createState() => _ShellState();
}

enum _Page { overview, servers, accounts, settings, logs, about }

class _ShellState extends State<Shell> {
  _Page _page = _Page.overview;

  @override
  void initState() {
    super.initState();
    widget.core.addListener(_countTraffic);
    AndroidCore.homeRequests.addListener(_openHome);
  }

  @override
  void dispose() {
    widget.core.removeListener(_countTraffic);
    AndroidCore.homeRequests.removeListener(_openHome);
    super.dispose();
  }

  /// The traffic through the VPN goes into the month's count (the home
  /// page's usage card), whichever page shows.
  void _countTraffic() {
    final t = widget.core.status?.traffic;
    if (t != null) widget.settings.countTraffic(t.up + t.down);
  }

  /// The settings section the home page opened (Connection), until another
  /// page is chosen.
  SettingsSection? _settingsOpening;

  void _openHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _page = _Page.overview;
      _settingsOpening = null;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.core,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final core = widget.core;
      final status = core.status;
      final needsAttention = (core.accounts?.accounts ?? const [])
          .where((a) => a.enabled && a.needsSignIn)
          .length;
      if (widget.settings.firstRun && status != null) {
        return WelcomePage(core: core, settings: widget.settings);
      }
      final pages = [
        _Page.overview,
        _Page.servers,
        _Page.accounts,
        _Page.settings,
        _Page.logs,
        _Page.about,
      ];
      final page = pages.contains(_page) ? _page : _Page.overview;
      Widget accountsIcon(IconData icon) => Badge(
        isLabelVisible: needsAttention > 0,
        label: Text('$needsAttention'),
        child: Icon(icon),
      );
      // Each page's icons and name, for the side menu and the bottom bar.
      final items = [
        for (final page in pages)
          switch (page) {
            _Page.overview => (
              const Icon(Icons.dashboard_outlined),
              const Icon(Icons.dashboard_rounded),
              l.navHome,
            ),
            _Page.servers => (
              const Icon(Icons.public_outlined),
              const Icon(Icons.public_rounded),
              l.navServers,
            ),
            _Page.accounts => (
              accountsIcon(Icons.people_outline_rounded),
              accountsIcon(Icons.people_rounded),
              l.navAccounts,
            ),
            _Page.settings => (
              const Icon(Icons.settings_outlined),
              const Icon(Icons.settings_rounded),
              l.navSettings,
            ),
            _Page.logs => (
              const Icon(Icons.receipt_long_outlined),
              const Icon(Icons.receipt_long_rounded),
              l.navLogs,
            ),
            _Page.about => (
              const Icon(Icons.info_outline_rounded),
              const Icon(Icons.info_rounded),
              l.navAbout,
            ),
          },
      ];
      final content = Column(
        children: [
          if (core.unavailable != null && status != null) const _LostBanner(),
          Expanded(
            child: status == null
                ? _NoCore(core: core)
                : switch (page) {
                    // Its cards open the pages beside it.
                    _Page.overview => OverviewPage(
                      core: core,
                      settings: widget.settings,
                      onOpenServers: () =>
                          setState(() => _page = _Page.servers),
                      onOpenAccounts: () =>
                          setState(() => _page = _Page.accounts),
                      onOpenConnection: () => setState(() {
                        _page = _Page.settings;
                        _settingsOpening = SettingsSection.connection;
                      }),
                      onOpenAbout: () => setState(() => _page = _Page.about),
                      onOpenUpstreamProxy: () => setState(() {
                        _page = _Page.settings;
                        _settingsOpening = SettingsSection.upstreamProxy;
                      }),
                    ),
                    _Page.servers => ServersPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.accounts => AccountsPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.settings => SettingsPage(
                      key: ValueKey(_settingsOpening),
                      core: core,
                      settings: widget.settings,
                      opening: _settingsOpening,
                      onOpenLogs: () => setState(() => _page = _Page.logs),
                    ),
                    _Page.logs => LogsPage(
                      core: core,
                      settings: widget.settings,
                    ),
                    _Page.about => AboutPage(core: core),
                  },
          ),
        ],
      );
      // The side menu's pages.
      const menu = [_Page.overview, _Page.settings, _Page.logs];
      void select(int i) => setState(() {
        _page = pages[i];
        _settingsOpening = null;
      });
      // Android (a phone, or a tablet in either orientation) and a narrow
      // window: the phone layout, Home and Settings. The computer layout
      // offers computer-only choices, such as Windows' system proxy.
      if (Platform.isAndroid || MediaQuery.sizeOf(context).width < 640) {
        return MobileShell(
          core: core,
          settings: widget.settings,
          banner: core.unavailable != null && status != null
              ? const _LostBanner()
              : null,
          noCore: status == null ? _NoCore(core: core) : null,
        );
      }
      return Scaffold(
        body: AnnouncementOverlay(
          settings: widget.settings,
          onOpenUpdates: () => setState(() => _page = _Page.about),
          child: Row(
            children: [
              // Home, Settings and Logs; the account at the bottom. The server
              // list and About open from the home page.
              _PillNav(
                items: [
                  for (final pg in menu) items[pages.indexOf(pg)],
                ],
                selected: menu.indexOf(page),
                onSelected: (i) => select(pages.indexOf(menu[i])),
                attention: needsAttention,
                accountLabel: status?.activeAccount?.email.split('@').first ?? '',
                accountsSelected: page == _Page.accounts,
                onAccounts: () => setState(() {
                  _page = _Page.accounts;
                  _settingsOpening = null;
                }),
              ),
              // A maximized window: the pages stay as wide as reads well; the
              // home page, centered by itself, keeps its colors to the edges.
              Expanded(
                child: page == _Page.overview || status == null
                    ? content
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: content,
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _LostBanner extends StatelessWidget {
  const _LostBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: StatusColors.bad.withValues(alpha: 0.14),
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.link_off_rounded, size: 18, color: StatusColors.bad),
        const SizedBox(width: 10),
        Expanded(child: Text(AppLocalizations.of(context).coreLost)),
      ],
    ),
  );
}

class _NoCore extends StatelessWidget {
  const _NoCore({required this.core});

  final CoreController core;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final problem = core.unavailable;
    final portTaken =
        problem != null &&
        (problem.problem == CoreProblem.portInUse ||
            problem.problem == CoreProblem.refused);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (problem == null || problem.problem == CoreProblem.starting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.startingCore, style: theme.textTheme.titleMedium),
            ] else ...[
              Icon(
                Icons.power_off_rounded,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(l.cantReachCore, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                describeProblem(l, problem),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  if (portTaken && core.moveStoppedCore != null)
                    FilledButton.icon(
                      onPressed: () async {
                        final port = await showPortDialog(
                          context,
                          taken: problem.detail,
                        );
                        if (port != null && context.mounted) {
                          await runShowingErrors(
                            context,
                            () => core.setAppPort(port),
                          );
                        }
                      },
                      icon: const Icon(Icons.settings_ethernet_rounded),
                      label: Text(l.changePort),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: core.retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l.retry),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The computer's side menu: a dark capsule of Home, Settings and Logs, the
/// chosen one lit in green, and the account (its page) at the bottom.
class _PillNav extends StatelessWidget {
  const _PillNav({
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.attention,
    required this.accountLabel,
    required this.accountsSelected,
    required this.onAccounts,
  });

  /// Each entry's icon, chosen icon and name.
  final List<(Widget, Widget, String)> items;
  final int selected;
  final ValueChanged<int> onSelected;

  /// Accounts that need signing in again.
  final int attention;

  /// The account's name under its picture ("Accounts" when empty).
  final String accountLabel;
  final bool accountsSelected;
  final VoidCallback onAccounts;

  static const _green = Color(0xFF1FBF84);
  static const _idle = Color(0xFF9AA0AE);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget entry({
      required Widget icon,
      required String label,
      required bool on,
      required VoidCallback onTap,
    }) {
      final color = on ? Colors.white : _idle;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          child: Material(
            color: on ? _green : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 72,
                height: 66,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconTheme(
                      data: IconThemeData(color: color, size: 24),
                      child: icon,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 0, 16),
      child: Center(
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F13),
            borderRadius: BorderRadius.circular(46),
            border: Border.all(color: const Color(0x22FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++)
                entry(
                  icon: i == selected ? items[i].$2 : items[i].$1,
                  label: items[i].$3,
                  on: i == selected,
                  onTap: () => onSelected(i),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Divider(height: 1, color: Color(0x22FFFFFF)),
              ),
              Tooltip(
                message: l.navAccounts,
                child: InkWell(
                  onTap: onAccounts,
                  borderRadius: BorderRadius.circular(30),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Badge(
                          isLabelVisible: attention > 0,
                          label: Text('$attention'),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accountsSelected
                                    ? _green
                                    : const Color(0x33FFFFFF),
                                width: 2,
                              ),
                            ),
                            child: const AppLogo(size: 40),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          accountLabel.isEmpty ? l.navAccounts : accountLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: accountsSelected ? _green : _idle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
