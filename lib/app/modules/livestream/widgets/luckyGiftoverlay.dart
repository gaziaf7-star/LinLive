import 'package:flutter/material.dart';

/// Lightweight screenshot-style Lucky result overlay.
/// AudioLiveView uses the queue-layer version inside gifts_animation.dart;
/// this widget keeps other live pages compatible without coin-rain or dozens
/// of animated children.
class LuckyGiftVideoStyleOverlay extends StatefulWidget {
  final Map<String, dynamic> data;

  const LuckyGiftVideoStyleOverlay({
    super.key,
    required this.data,
  });

  @override
  State<LuckyGiftVideoStyleOverlay> createState() =>
      _LuckyGiftVideoStyleOverlayState();
}

class _LuckyGiftVideoStyleOverlayState
    extends State<LuckyGiftVideoStyleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant LuckyGiftVideoStyleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_eventKey(oldWidget.data) != _eventKey(widget.data)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _eventKey(Map<String, dynamic> data) => <dynamic>[
    data['gift_event_id'],
    data['event_id'],
    data['lucky_result_serial'],
    data['timestamp'],
    data['combo_count'],
    data['multiplier'],
    data['win_amount'],
  ].join('|');

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  double get _multiplier {
    final result = _map(widget.data['lucky_result']);
    return double.tryParse(
      '${widget.data['multiplier'] ?? widget.data['gun'] ?? widget.data['multiple'] ?? result['multiplier'] ?? 0}',
    ) ??
        0;
  }

  int get _winAmount {
    final result = _map(widget.data['lucky_result']);
    return int.tryParse(
      '${widget.data['win_amount'] ?? widget.data['back_coin'] ?? widget.data['win_coin'] ?? result['win_amount'] ?? 0}',
    ) ??
        0;
  }

  String _formatCoin(int value) {
    if (value >= 1000000) {
      final n = value / 1000000;
      return '${n % 1 == 0 ? n.toInt() : n.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final n = value / 1000;
      return '${n % 1 == 0 ? n.toInt() : n.toStringAsFixed(1)}K';
    }
    return '$value';
  }

  String _formatMultiplier(double value) =>
      value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    if (_multiplier <= 0 && _winAmount <= 0) {
      return const SizedBox.shrink();
    }

    final Size size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final double t = _controller.value;
        final double appear = (t / .12).clamp(0.0, 1.0).toDouble();
        final double fade = t < .84
            ? 1
            : (1 - ((t - .84) / .16)).clamp(0.0, 1.0).toDouble();

        return Positioned(
          left: (size.width - 154) / 2,
          top: (size.height * .48) - 77,
          child: Opacity(
            opacity: appear * fade,
            child: Transform.scale(
              scale: .94 + (.06 * Curves.easeOutCubic.transform(appear)),
              child: Container(
                width: 154,
                height: 154,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: <Color>[
                      Color(0xfff5b34c),
                      Color(0xffc84c16),
                      Color(0xff7d1208),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xffffe589),
                    width: 4,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Color(0x77000000), blurRadius: 12),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text(
                      'WIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 31,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: Color(0xffffd75c),
                      size: 23,
                    ),
                    Text(
                      _formatCoin(_winAmount),
                      style: const TextStyle(
                        color: Color(0xfffff0c0),
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.28),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xffffdb73)),
                      ),
                      child: Text(
                        'x${_formatMultiplier(_multiplier <= 0 ? 1 : _multiplier)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kept for API compatibility. Coin rain was a major source of overdraw during
/// Combo spam, so the professional mode intentionally renders nothing here.
class LuckyCoinRainOverlay extends StatelessWidget {
  const LuckyCoinRainOverlay({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
