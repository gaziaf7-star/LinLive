import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/modules/store/views/store1_view.dart';
import 'package:meetlivepro/app/modules/withdraw/views/withdraw_view.dart';
import 'package:meetlivepro/constants/constants.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
Widget premiumShortcutMenu({
  required double kHeight,
  required double kWeight,
}) {
  return Obx(() {
    // Keep this card group reactive to language and account-role changes.
    AppLanguageController.to.currentLocaleKey.value;
    authController.userProfile.value.user?.hostType;
    authController.userProfile.value.user?.agencyType;

    return _PremiumShortcutMenu(
      kHeight: kHeight,
      kWeight: kWeight,
    );
  });
}

class _PremiumShortcutMenu extends StatelessWidget {
  final double kHeight;
  final double kWeight;

  const _PremiumShortcutMenu({
    required this.kHeight,
    required this.kWeight,
  });

  num get _userCoins {
    final dynamic coinValue = authController.userProfile.value.user?.levelCoins;

    return coinValue is num
        ? coinValue
        : num.tryParse(coinValue?.toString() ?? '0') ?? 0;
  }

  bool get _canShowRecharge => _userCoins >= 10;

  @override
  Widget build(BuildContext context) {
    final currentUser = authController.userProfile.value.user;

    // Agency has first priority.
    // Agency + Host => Creator visible.
    // Host only => Creator hidden.
    final bool isAgency = currentUser?.isAgencyAccount ?? false;
    final bool isHost = currentUser?.isHostAccount ?? false;
    final bool canShowCreator = isAgency || !isHost;

    final items = <_PremiumItem>[
      if (_canShowRecharge)
        _PremiumItem(
          title: 'Host Center'.appTr,
          image: 'assets/frame/retreat.png',
          fallbackIcon: Icons.account_balance_wallet_rounded,
          bgColors: const [
            Color(0xff3203a1),
            Color(0xff5306c5),
          ],
          glowColor: const Color(0xff86EFAC),
          onTap: () {
            if (_userCoins < 1) return;

            Get.to(
              WithdrawView(),
              transition: Transition.rightToLeft,
            );
          },
        ),
      _PremiumItem(
        title: 'Mall'.appTr,
        image: 'assets/icons/online-shopping.png',
        fallbackIcon: Icons.shopping_bag_rounded,
        bgColors: const [
          Color(0xffF59E0B),
          Color(0xff92400E),
        ],
        glowColor: const Color(0xffFDE68A),
        onTap: () {
          Get.to(
            Store1View(),
            transition: Transition.rightToLeft,
          );
        },
      ),
      if (canShowCreator)
        _PremiumItem(
          title: 'Creator'.appTr,
          image: 'assets/flaticons/government.png',
          fallbackIcon: Icons.verified_user_rounded,
          bgColors: const [
            Color(0xff38BDF8),
            Color(0xff1E3A8A),
          ],
          glowColor: const Color(0xffBAE6FD),
          onTap: () {
            verifiedController.showNewAgenctList();
          },
        ),
      _PremiumItem(
        title: 'Badge'.appTr,
        image: 'assets/icons/verify.png',
        fallbackIcon: Icons.workspace_premium_rounded,
        bgColors: const [
          Color(0xfffa0d0d),
          Color(0xff831843),
        ],
        glowColor: const Color(0xffF9A8D4),
        onTap: () {
          // Get.to(BadgeView());
        },
      ),
    ];

    return SizedBox(
      height: kHeight * 0.084,
      child: Row(
        children: List.generate(items.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == items.length - 1 ? 0 : kWeight * 0.014,
              ),
              child: _PremiumMiniCard(
                item: items[index],
                index: index,
                kHeight: kHeight,
                kWeight: kWeight,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PremiumMiniCard extends StatefulWidget {
  final _PremiumItem item;
  final int index;
  final double kHeight;
  final double kWeight;

  const _PremiumMiniCard({
    required this.item,
    required this.index,
    required this.kHeight,
    required this.kWeight,
  });

  @override
  State<_PremiumMiniCard> createState() => _PremiumMiniCardState();
}

class _PremiumMiniCardState extends State<_PremiumMiniCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();

    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double cardHeight = widget.kHeight * 0.074;
    final double radius = widget.kHeight * 0.016;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + (widget.index * 80)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 13 * (1 - value)),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapCancel: () => setState(() => _isPressed = false),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.item.onTap();
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.955 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Container(
            height: cardHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.item.bgColors,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.item.bgColors.last.withOpacity(0.28),
                  blurRadius: 13,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: widget.item.glowColor.withOpacity(0.16),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  /// Soft premium surface.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.20),
                            Colors.white.withOpacity(0.035),
                            Colors.black.withOpacity(0.12),
                          ],
                          stops: const [0.0, 0.48, 1.0],
                        ),
                      ),
                    ),
                  ),

                  /// Big category watermark icon.
                  Positioned(
                    right: -widget.kHeight * 0.018,
                    bottom: -widget.kHeight * 0.020,
                    child: Icon(
                      widget.item.fallbackIcon,
                      size: widget.kHeight * 0.082,
                      color: Colors.white.withOpacity(0.085),
                    ),
                  ),

                  /// Bottom glow shape.
                  Positioned(
                    right: -widget.kHeight * 0.012,
                    bottom: -widget.kHeight * 0.026,
                    child: Container(
                      height: widget.kHeight * 0.072,
                      width: widget.kHeight * 0.072,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            widget.item.glowColor.withOpacity(0.36),
                            widget.item.glowColor.withOpacity(0.16),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.48, 1.0],
                        ),
                      ),
                    ),
                  ),

                  /// Small top glow.
                  Positioned(
                    left: -widget.kHeight * 0.020,
                    top: -widget.kHeight * 0.035,
                    child: Container(
                      height: widget.kHeight * 0.075,
                      width: widget.kHeight * 0.075,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.09),
                      ),
                    ),
                  ),

                  /// Animated shine overlay.
                  AnimatedBuilder(
                    animation: _shineController,
                    builder: (context, child) {
                      return Positioned.fill(
                        child: ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (bounds) {
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.20),
                                Colors.transparent,
                              ],
                              stops: const [0.25, 0.50, 0.75],
                              transform: _SlidingGradientTransform(
                                slidePercent: _shineController.value,
                              ),
                            ).createShader(bounds);
                          },
                          child: Container(
                            color: Colors.white.withOpacity(0.035),
                          ),
                        ),
                      );
                    },
                  ),


                  /// Title - full visible on every card.
                  /// The title uses FittedBox so Withdraw / Mall / Creator / Badge
                  /// will not be clipped on small card width.
                  Positioned(
                    top: widget.kHeight * 0.008,
                    left: widget.kWeight * 0.014,
                    right: widget.kWeight * 0.014,
                    child: SizedBox(
                      height: widget.kHeight * 0.020,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.item.title,
                          maxLines: 1,
                          softWrap: false,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: widget.kHeight * 0.0130,
                            height: 1.0,
                            letterSpacing: 0.05,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 5,
                                offset: const Offset(0, 1.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // /// Small subtitle line.

                  //
                  /// Visible asset icon area.
                  Positioned(
                    right: widget.kWeight * 0.004,
                    bottom: widget.kHeight * 0.003,
                    child: _CardVisibleIconArea(
                      item: widget.item,
                      kHeight: widget.kHeight,
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
}

class _CardVisibleIconArea extends StatelessWidget {
  final _PremiumItem item;
  final double kHeight;

  const _CardVisibleIconArea({
    required this.item,
    required this.kHeight,
  });

  @override
  Widget build(BuildContext context) {
    final double boxSize = kHeight * 0.049;
    final double iconSize = kHeight * 0.034;

    return SizedBox(
      height: boxSize,
      width: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          /// White glass badge keeps every image visible on any card color.
          Container(
            height: kHeight * 0.045,
            width: kHeight * 0.045,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.48),
                  Colors.white.withOpacity(0.22),
                  item.glowColor.withOpacity(0.13),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 0.78, 1.0],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.28),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.14),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),

          /// Icon shadow.
          Transform.translate(
            offset: Offset(kHeight * 0.0018, kHeight * 0.0028),
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                item.image,
                height: iconSize,
                width: iconSize,
                fit: BoxFit.contain,
                color: Colors.black,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    item.fallbackIcon,
                    size: iconSize,
                    color: Colors.black,
                  );
                },
              ),
            ),
          ),

          /// Main icon/image. No ShaderMask here, so image will not vanish.
          Transform.rotate(
            angle: -0.055,
            child: Image.asset(
              item.image,
              height: iconSize,
              width: iconSize,
              fit: BoxFit.contain,
              opacity: const AlwaysStoppedAnimation<double>(0.96),
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: iconSize,
                  width: iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.12),
                  ),
                  child: Icon(
                    item.fallbackIcon,
                    size: iconSize * 0.72,
                    color: Colors.white.withOpacity(0.95),
                  ),
                );
              },
            ),
          ),

          /// Tiny gloss highlight.
          Positioned(
            top: kHeight * 0.006,
            left: kHeight * 0.010,
            child: Container(
              height: kHeight * 0.008,
              width: kHeight * 0.017,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.48),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticleDot extends StatelessWidget {
  final double size;

  const _ParticleDot({
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.26),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PremiumItem {
  final String title;
  final String image;
  final IconData fallbackIcon;
  final List<Color> bgColors;
  final Color glowColor;
  final VoidCallback onTap;

  const _PremiumItem({
    required this.title,
    required this.image,
    required this.fallbackIcon,
    required this.bgColors,
    required this.glowColor,
    required this.onTap,
  });
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({
    required this.slidePercent,
  });

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2.6 - 1.3),
      0,
      0,
    );
  }
}
