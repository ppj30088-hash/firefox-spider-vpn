import 'package:flutter/material.dart';

/// The pill navigation bar: a dark capsule whose chosen item grows into a
/// green pill, its name sliding out from behind the icon. The motion follows
/// the web demo: the pill grows in 620 ms on a spring, the name fades and
/// slides in behind it, a tap presses it down a little, and the page above
/// swaps with a bounce. One widget for the phone's bottom bar (horizontal)
/// and the computer's side menu (vertical), so every system shows the same
/// menu.
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelected,
    this.axis = Axis.horizontal,
    this.attentionIndex,
    this.attention = 0,
    this.capsule = true,
  });

  /// Each entry's icon, chosen icon and name.
  final List<(Widget, Widget, String)> items;
  final int selected;
  final ValueChanged<int> onSelected;
  final Axis axis;

  /// The entry carrying the attention badge (accounts needing sign-in).
  final int? attentionIndex;
  final int attention;

  /// The dark capsule around the entries; false leaves only the entries,
  /// for a menu that already has its own capsule.
  final bool capsule;

  static const green = Color(0xFF1FBF84);
  static const idle = Color(0xFF9AA0AE);
  static const bar = Color(0xFF0F0F13);

  /// The spring the pill grows with (620 ms).
  static const spring = Cubic(0.32, 0.72, 0, 1);

  /// The bounce the pill and the page swap settle with.
  static const bounce = Cubic(0.34, 1.56, 0.64, 1);

  /// The page swap: fade, rise a little and grow into place.
  static Widget swapTransition(Widget child, Animation<double> animation) {
    final curved = CurvedAnimation(parent: animation, curve: bounce);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    if (horizontal) {
      final content = LayoutBuilder(
        builder: (context, constraints) {
          // The demo shrinks the circles so the bar fits: (width - 142) / 5.
          final s = ((constraints.maxWidth - 142) / 5).clamp(38.0, 60.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                _PillItem(
                  icon: i == selected ? items[i].$2 : items[i].$1,
                  label: items[i].$3,
                  active: i == selected,
                  size: s,
                  horizontal: true,
                  badge: attentionIndex == i ? attention : 0,
                  onTap: () => onSelected(i),
                ),
              ],
            ],
          );
        },
      );
      if (!capsule) return content;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: bar,
          borderRadius: BorderRadius.circular(999),
        ),
        child: content,
      );
    }
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _PillItem(
            icon: i == selected ? items[i].$2 : items[i].$1,
            label: items[i].$3,
            active: i == selected,
            size: 52,
            horizontal: false,
            badge: attentionIndex == i ? attention : 0,
            onTap: () => onSelected(i),
          ),
        ],
      ],
    );
    if (!capsule) return content;
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bar,
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
      child: content,
    );
  }
}

/// One entry: a circle with an icon; the chosen one grows into a pill and
/// its name slides out from behind the icon, clipped at the icon's edge.
class _PillItem extends StatefulWidget {
  const _PillItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.size,
    required this.horizontal,
    required this.badge,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final bool active;
  final double size;
  final bool horizontal;
  final int badge;
  final VoidCallback onTap;

  @override
  State<_PillItem> createState() => _PillItemState();
}

class _PillItemState extends State<_PillItem> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final scale = _pressed ? 0.97 : _hovered ? 1.07 : 1.0;
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.label,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 520),
        curve: PillNavBar.bounce,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.active ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 620),
          curve: PillNavBar.spring,
          builder: (context, t, child) {
            final bg = Color.lerp(Colors.transparent, PillNavBar.green, t)!;
            final fg = Color.lerp(PillNavBar.idle, Colors.white, t)!;
            return Material(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                onHover: (v) => setState(() => _hovered = v),
                splashColor: PillNavBar.green.withValues(alpha: 0.38),
                child: Container(
                  width: widget.horizontal ? null : 72,
                  padding: EdgeInsetsDirectional.only(end: 16 * t),
                  child: widget.horizontal
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _icon(fg),
                            _name(t, fg, rtl: rtl),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _icon(fg),
                            _name(t, fg, rtl: rtl),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The icon in its circle, with the attention badge on its corner.
  Widget _icon(Color fg) {
    final icon = IconTheme(
      data: IconThemeData(size: widget.size * 0.54, color: fg),
      child: widget.icon,
    );
    final badged = widget.badge > 0
        ? Badge(label: Text('${widget.badge}'), child: icon)
        : icon;
    return SizedBox.square(dimension: widget.size, child: Center(child: badged));
  }

  /// The name, clipped at the icon's edge and sliding out as the pill grows.
  Widget _name(double t, Color fg, {required bool rtl}) {
    final opacity = const Interval(
      0.2,
      1.0,
      curve: Curves.easeOut,
    ).transform(t);
    final text = Text(
      widget.label,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(
        fontSize: widget.horizontal ? 15 : 11,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    );
    final sliding = Opacity(
      opacity: opacity,
      child: FractionalTranslation(
        translation: widget.horizontal
            ? Offset((1 - t) * 0.7 * (rtl ? 1 : -1), 0)
            : Offset(0, (1 - t) * -0.7),
        child: text,
      ),
    );
    if (widget.horizontal) {
      return ClipRect(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: t,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 10),
            child: sliding,
          ),
        ),
      );
    }
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: t,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: sliding,
        ),
      ),
    );
  }
}
