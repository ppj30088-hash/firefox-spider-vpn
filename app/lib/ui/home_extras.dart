import 'dart:async';

import 'package:flutter/material.dart';

import '../core/core_controller.dart';

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
