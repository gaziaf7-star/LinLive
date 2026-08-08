import 'package:flutter/material.dart';
import 'dart:math' as math;

class RedPacketAnimation extends StatefulWidget {
  final VoidCallback? onTap;
  final bool isVisible;
  final Duration duration;

  const RedPacketAnimation({
    Key? key,
    this.onTap,
    this.isVisible = false,
    this.duration = const Duration(seconds: 5),
  }) : super(key: key);

  @override
  State<RedPacketAnimation> createState() => _RedPacketAnimationState();
}

class _RedPacketAnimationState extends State<RedPacketAnimation>
    with TickerProviderStateMixin {
  late AnimationController _flyController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  
  late Animation<double> _flyAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  
  List<CoinWidget> coins = [];
  bool _isCollected = false;

  @override
  void initState() {
    super.initState();
    
    _flyController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _flyAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _flyController,
      curve: Curves.easeOutQuart,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.elasticInOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotateController,
      curve: Curves.linear,
    ));

    if (widget.isVisible) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _generateCoins();
    _flyController.forward();
    _pulseController.repeat(reverse: true);
    _rotateController.repeat();
    
    // Auto hide after duration
    Future.delayed(widget.duration, () {
      if (mounted && !_isCollected) {
        _hideAnimation();
      }
    });
  }

  void _generateCoins() {
    coins.clear();
    final random = math.Random();
    
    for (int i = 0; i < 8; i++) {
      coins.add(CoinWidget(
        delay: Duration(milliseconds: i * 200),
        startX: random.nextDouble() * 300,
        startY: random.nextDouble() * 200,
        endX: random.nextDouble() * 300,
        endY: random.nextDouble() * 200,
      ));
    }
  }

  void _hideAnimation() {
    _flyController.reverse();
    _pulseController.stop();
    _rotateController.stop();
  }

  void _onRedPacketTap() {
    if (!_isCollected && widget.onTap != null) {
      setState(() {
        _isCollected = true;
      });
      widget.onTap!();
      _hideAnimation();
    }
  }

  @override
  void didUpdateWidget(RedPacketAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _isCollected = false;
      _startAnimation();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _hideAnimation();
    }
  }

  @override
  void dispose() {
    _flyController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([_flyAnimation, _pulseAnimation, _rotateAnimation]),
      builder: (context, child) {
        return Stack(
          children: [
            // Flying coins animation
            ...coins.map((coin) => coin.buildAnimated(_flyAnimation)),
            
            // Red packet in center
            Positioned(
              left: MediaQuery.of(context).size.width * 0.5 - 40,
              top: MediaQuery.of(context).size.height * 0.4,
              child: Transform.scale(
                scale: _pulseAnimation.value,
                child: Transform.rotate(
                  angle: _rotateAnimation.value * 0.1,
                  child: GestureDetector(
                    onTap: _onRedPacketTap,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.card_giftcard,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CoinWidget {
  final Duration delay;
  final double startX;
  final double startY;
  final double endX;
  final double endY;

  CoinWidget({
    required this.delay,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
  });

  Widget buildAnimated(Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = math.max(0.0, (animation.value * 1000 - delay.inMilliseconds) / 1000);
        final clampedProgress = math.min(1.0, math.max(0.0, progress));
        
        final currentX = startX + (endX - startX) * clampedProgress;
        final currentY = startY + (endY - startY) * clampedProgress;
        
        return Positioned(
          left: currentX,
          top: currentY,
          child: Opacity(
            opacity: clampedProgress > 0 ? (1.0 - clampedProgress) : 0.0,
            child: Transform.rotate(
              angle: clampedProgress * 4 * math.pi,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD700),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange,
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
