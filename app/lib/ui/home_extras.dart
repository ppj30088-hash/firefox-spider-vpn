import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/core_controller.dart';
import '../core/models.dart';
import 'widgets.dart';

/// A small line chart of the last values, smooth, with a soft fill under
/// the line and a dot at its end (the computer home's speed cards).
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 44,
  });

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _SparkPainter(List.of(values), color)),
  );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      base,
    );
    if (values.length < 2) return;
    var top = 0.0;
    for (final v in values) {
      if (v > top) top = v;
    }
    if (top <= 0) top = 1;
    const pad = 4.0;
    final h = size.height - pad * 2;
    final step = size.width / (values.length - 1);
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(i * step, pad + h - h * (values[i] / top)),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
    canvas.drawCircle(
      points.last,
      3.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.color != color || old.values != values;
}

/// The time since the connection began, "00:45:29", ticking each second;
/// zeros while there is no [since].
class ConnectedTimer extends StatefulWidget {
  const ConnectedTimer({super.key, required this.since, this.style});

  final DateTime? since;
  final TextStyle? style;

  @override
  State<ConnectedTimer> createState() => _ConnectedTimerState();
}

class _ConnectedTimerState extends State<ConnectedTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.since != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    final d = since == null
        ? Duration.zero
        : DateTime.now().difference(since).isNegative
        ? Duration.zero
        : DateTime.now().difference(since);
    String two(int n) => n.toString().padLeft(2, '0');
    final text =
        '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:'
        '${two(d.inSeconds.remainder(60))}';
    return Text(
      text,
      textDirection: TextDirection.ltr,
      style: widget.style?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// The last minute of the download and upload speeds and of the connection
/// test's delay, taken from the core's status each time it changes, for the
/// speed cards' charts.
class RateHistory extends StatefulWidget {
  const RateHistory({super.key, required this.core, required this.builder});

  final CoreController core;
  final Widget Function(
    BuildContext context,
    List<double> down,
    List<double> up,
    List<double> delay,
  )
  builder;

  @override
  State<RateHistory> createState() => _RateHistoryState();
}

class _RateHistoryState extends State<RateHistory> {
  static const _keep = 60;
  final _down = <double>[];
  final _up = <double>[];
  final _delay = <double>[];
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.core.addListener(_sample);
    _sample();
  }

  @override
  void dispose() {
    widget.core.removeListener(_sample);
    super.dispose();
  }

  void _sample() {
    // At most once a second.
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(milliseconds: 900)) return;
    _last = now;
    final t = widget.core.status?.traffic;
    final test = widget.core.lastTest;
    void add(List<double> list, double v) {
      list.add(v);
      if (list.length > _keep) list.removeAt(0);
    }

    add(_down, (t?.downRate ?? 0).toDouble());
    add(_up, (t?.upRate ?? 0).toDouble());
    add(_delay, test != null && test.ok ? test.responseMs.toDouble() : 0);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _down, _up, _delay);
}

/// The world, faint, behind the home page: its land in [color].
class WorldMap extends StatelessWidget {
  const WorldMap({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Image.asset(
        'assets/world_map.png',
        color: color,
        colorBlendMode: BlendMode.srcIn,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}

/// A flag in a circle, [size] across.
class RoundFlag extends StatelessWidget {
  const RoundFlag({super.key, required this.code, required this.size});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: OverflowBox(
        maxWidth: size * 4 / 3,
        child: CountryFlag(code: code, width: size * 4 / 3),
      ),
    ),
  );
}

/// The channel the Telegram button opens.
const telegramUrl = 'https://t.me/SPiDER_VPN1';

/// A round Telegram button, its paper plane in white on Telegram's blue; it
/// opens [telegramUrl]. Put at the end of a row, it sits at the left of a
/// right-to-left language (Persian) and at the right of the others.
class TelegramButton extends StatelessWidget {
  const TelegramButton({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Telegram',
    child: Material(
      color: const Color(0xFF27A7E7),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openLink(context, telegramUrl),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _PlanePainter()),
        ),
      ),
    ),
  );
}

class _PlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Offset at(double x, double y) => Offset(x * size.width, y * size.height);
    final plane = Path()
      ..moveTo(at(0.20, 0.50).dx, at(0.20, 0.50).dy)
      ..lineTo(at(0.78, 0.27).dx, at(0.78, 0.27).dy)
      ..lineTo(at(0.66, 0.75).dx, at(0.66, 0.75).dy)
      ..lineTo(at(0.50, 0.62).dx, at(0.50, 0.62).dy)
      ..lineTo(at(0.41, 0.72).dx, at(0.41, 0.72).dy)
      ..lineTo(at(0.40, 0.58).dx, at(0.40, 0.58).dy)
      ..close();
    canvas.drawPath(plane, Paint()..color = Colors.white);
    // The fold of the plane, a thin line in the button's blue.
    canvas.drawLine(
      at(0.40, 0.58),
      at(0.70, 0.38),
      Paint()
        ..color = const Color(0xFF27A7E7)
        ..strokeWidth = size.width * 0.035
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_PlanePainter old) => false;
}

/// The location as a row of flags: the chosen one large in the middle, in a
/// ring, with its name below, and the fastest other countries small on both
/// sides. A tap on a small flag chooses that country and connects to it;
/// a swipe to the right takes the country at the right of the large flag, a
/// swipe to the left the one at its left. The large flag and the name open
/// the server list.
class FlagStrip extends StatefulWidget {
  const FlagStrip({
    super.key,
    required this.core,
    required this.place,
    required this.accent,
    required this.textColor,
    this.onTap,
    this.onPick,
    this.small = 3,
    this.big = 66,
  });

  final CoreController core;
  final HomePlace place;
  final Color accent;
  final Color textColor;

  /// Opens the server list.
  final VoidCallback? onTap;

  /// Chooses [code] and connects to it (the home page knows how).
  final Future<void> Function(BuildContext context, String code)? onPick;

  /// How many small flags at most on each side.
  final int small;

  /// The large flag's diameter.
  final double big;

  @override
  State<FlagStrip> createState() => _FlagStripState();
}

class _FlagStripState extends State<FlagStrip> {
  List<String> _codes = const [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.core.call((api) => api.locations());
      final found = [
        for (final loc in list.locations)
          if (!isRecommendedPlace(loc.code) && loc.code.length == 2) loc,
      ];
      found.sort((a, b) {
        final da = a.answered ? a.pingMs : 1 << 30;
        final db = b.answered ? b.pingMs : 1 << 30;
        return da.compareTo(db);
      });
      if (mounted) setState(() => _codes = [for (final c in found) c.code]);
    } catch (_) {
      // No list yet: the large flag alone.
    }
  }

  Future<void> _pick(String code) async {
    final pick = widget.onPick;
    if (pick == null || _busy) {
      widget.onTap?.call();
      return;
    }
    setState(() => _busy = true);
    try {
      await pick(context, code);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = widget.place.flag.toUpperCase();
    final others = [
      for (final c in _codes)
        if (c.toUpperCase() != current) c,
    ].take(widget.small * 2).toList();
    final half = (others.length + 1) ~/ 2;
    final left = others.take(half).toList();
    final right = others.skip(half).toList();
    Widget small(String code, double size) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkResponse(
        onTap: () => _pick(code),
        radius: size,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Opacity(
            opacity: 0.85,
            child: RoundFlag(code: code, size: size),
          ),
        ),
      ),
    );
    // Smaller the farther from the middle.
    double sizeAt(int distance) => math.max(20, 36 - 5.0 * distance);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // A swipe to the right takes the country at the right of the large
      // flag, a swipe to the left the one at its left.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v > 250 && right.isNotEmpty) {
          _pick(right.first);
        } else if (v < -250 && left.isNotEmpty) {
          _pick(left.last);
        }
      },
      child: Opacity(
        opacity: _busy ? 0.55 : 1,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Left is left in every language.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < left.length; i++)
                        small(left[i], sizeAt(left.length - 1 - i)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: widget.accent.withValues(alpha: 0.75),
                              width: 2.5,
                            ),
                          ),
                          child: RoundFlag(
                            code: widget.place.flag,
                            size: widget.big,
                          ),
                        ),
                      ),
                      for (var i = 0; i < right.length; i++)
                        small(right[i], sizeAt(i)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.place.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: widget.textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
