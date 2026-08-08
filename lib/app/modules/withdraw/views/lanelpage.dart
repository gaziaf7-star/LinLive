import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/layout_constant.dart';
import 'package:meetlivepro/widgets/after/castom%20appbar.dart';

import '../controllers/withdraw_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MyLevelPage extends StatefulWidget {
  const MyLevelPage({super.key});

  @override
  State<MyLevelPage> createState() => _MyLevelPageState();
}

class _MyLevelPageState extends State<MyLevelPage> {
  final WithdrawController controller = Get.put(WithdrawController());

  @override
  void initState() {
    super.initState();
    controller.myLevelList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    return Scaffold(
      backgroundColor: const Color(0xfffaf7ff),
      appBar: CustomAppBar(title: ('My Level').appTr),
      body: SafeArea(
        child: Obx(() {
          if (controller.myLevelLoading.value &&
              controller.mylevellist.isEmpty) {
            return _LevelLoadingView(width: w);
          }

          final currentLevel = controller.currentLevelData;
          final nextLevel = controller.nextLevelData;

          return RefreshIndicator(
            color: const Color(0xff8A4CF7),
            onRefresh: controller.myLevelList,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: w * 0.02,
                vertical: h * 0.02,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LevelHeaderCard(
                    width: w,
                    controller: controller,
                    currentLevel: currentLevel,
                    nextLevel: nextLevel,
                  ),

                  SizedBox(height: h * 0.026),

                  _CoinStatusCard(
                    width: w,
                    controller: controller,
                  ),

                  SizedBox(height: h * 0.032),

                  Text(
                    ('How to upgrade').appTr,
                    style: GoogleFonts.poppins(
                      fontSize: (w * 0.058).clamp(21.0, 26.0),
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff2d2340),
                    ),
                  ),

                  SizedBox(height: h * 0.018),

                  ...controller.levelItems(currentLevel).asMap().entries.map(
                        (entry) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: h * 0.014),
                        child: _UpgradeItem(
                          number: '${entry.key + 1}',
                          title: entry.value,
                          text: _upgradeText(entry.value),
                        ),
                      );
                    },
                  ).toList(),

                  if (controller.levelItems(currentLevel).isEmpty) ...[
                     _UpgradeItem(
                      number: '1',
                      title: ('Recharge coins').appTr,
                      text:
                      ('Recharge coins to increase your profile level and unlock premium identity.').appTr,
                    ),
                    SizedBox(height: h * 0.014),
                     _UpgradeItem(
                      number: '2',
                      title: ('Gift sending').appTr,
                      text:
                      ('Send gifts in live rooms to grow your level activity faster.').appTr,
                    ),
                    SizedBox(height: h * 0.014),
                     _UpgradeItem(
                      number: '3',
                      title: ('Gift received').appTr,
                      text:
                      ('Receive gifts from users and improve your level progress.').appTr,
                    ),
                  ],

                  SizedBox(height: h * 0.026),

                  _AllLevelsSection(
                    controller: controller,
                    width: w,
                  ),

                  SizedBox(height: h * 0.03),

                  _noteBox(),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  static String _upgradeText(String title) {
    final lower = title.toLowerCase();

    if (lower.contains('reacharge') || lower.contains('recharge')) {
      return 'Recharge coins regularly to increase your level progress.';
    }

    if (lower.contains('sending')) {
      return 'Send gifts in live rooms and your level activity will grow.';
    }

    if (lower.contains('received')) {
      return 'Receive gifts from users to improve your level status.';
    }

    return 'Stay active and keep using premium platform features.';
  }

  Widget _noteBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xff8A4CF7).withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        ('Note: Level progress is calculated from your coins. Higher level unlocks stronger profile identity and premium frame appearance.').appTr,
        style: GoogleFonts.poppins(
          fontSize: 12.5,
          height: 1.5,
          color: const Color(0xff6f657d),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _LevelHeaderCard extends StatelessWidget {
  final double width;
  final WithdrawController controller;
  final Map<String, dynamic>? currentLevel;
  final Map<String, dynamic>? nextLevel;

  const _LevelHeaderCard({
    required this.width,
    required this.controller,
    required this.currentLevel,
    required this.nextLevel,
  });

  double _fixedProgress() {
    final bool isMaxLevel = nextLevel == null;

    if (isMaxLevel) {
      return 1.0;
    }

    final double targetCoins = controller.nextLevelNeedCoins <= 0
        ? 1.0
        : controller.nextLevelNeedCoins.toDouble();

    final double remainingCoins = max(
      controller.remainingCoinsForNextLevel.toDouble(),
      0.0,
    );

    final double calculatedProgress = 1.0 - (remainingCoins / targetCoins);

    if (calculatedProgress.isNaN || calculatedProgress.isInfinite) {
      return 0.0;
    }

    return calculatedProgress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = controller.levelImageUrl(
      currentLevel?['image']?.toString(),
    );

    final bool isMaxLevel = nextLevel == null;
    final double progress = _fixedProgress();
    final int percent = (progress * 100).clamp(0, 100).toInt();

    final String currentCoinsText =
    controller.formatLevelCoins(controller.myLevelCoins);

    final String targetCoinsText = isMaxLevel
        ? 'Max Level'
        : controller.formatLevelCoins(controller.nextLevelNeedCoins);

    final String remainingText = controller.formatLevelCoins(
      max(controller.remainingCoinsForNextLevel, 0),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.045,
        vertical: width * 0.055,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xff7D38F5),
            Color(0xffB45EF4),
            Color(0xffF25AA3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff8A4CF7).withOpacity(0.30),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            ('Current Level').appTr,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.88),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            ('LV ${controller.currentLevelStart} - ${controller.currentLevelEnd}').appTr,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 14),

          _LevelImageBox(
            width: width,
            imageUrl: imageUrl,
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentCoinsText,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.20),
                  ),
                ),
                child: Text(
                  '$percent%',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                targetCoinsText,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _GlowingProgressBar(progress: progress),

          const SizedBox(height: 14),

          Text(
            isMaxLevel
                ? ('Congratulations! You reached maximum level.').appTr: ('Ar matro $remainingText coins baki ache next level er jonno').appTr,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowingProgressBar extends StatefulWidget {
  final double progress;

  const _GlowingProgressBar({
    required this.progress,
  });

  @override
  State<_GlowingProgressBar> createState() => _GlowingProgressBarState();
}

class _GlowingProgressBarState extends State<_GlowingProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _glow = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = widget.progress.clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;

        double fillWidth = maxWidth * progress;

        if (progress > 0 && fillWidth < 18) {
          fillWidth = 18;
        }

        return Container(
          height: 20,
          width: double.infinity,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: Colors.white.withOpacity(0.30),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.white.withOpacity(0.16),
                ),
              ),

              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                width: fillWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xfffff6a5),
                      Color(0xffffd84d),
                      Color(0xffffa928),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffffd84d).withOpacity(0.75),
                      blurRadius: 18,
                      spreadRadius: 1.2,
                    ),
                    BoxShadow(
                      color: const Color(0xffffffff).withOpacity(0.45),
                      blurRadius: 8,
                      spreadRadius: 0.2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final double shineWidth = 42;
                      final double moveX =
                          (_controller.value * (fillWidth + shineWidth)) -
                              shineWidth;

                      return Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.12),
                                  Colors.white.withOpacity(0.00),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(moveX, 0),
                            child: Container(
                              width: shineWidth,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.00),
                                    Colors.white.withOpacity(
                                      0.55 * _glow.value,
                                    ),
                                    Colors.white.withOpacity(0.00),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelImageBox extends StatelessWidget {
  final double width;
  final String imageUrl;

  const _LevelImageBox({
    required this.width,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isSvga = imageUrl.toLowerCase().endsWith('.svga');

    return Container(
      width: width * 0.55,
      height: width * 0.25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withOpacity(0.28),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: imageUrl.isEmpty
            ? const Icon(
          Icons.workspace_premium_rounded,
          color: Colors.white,
          size: 82,
        )
            : isSvga
            ? SizedBox(
          height: kHeight * 0.07,
          width: kWeight * 0.7,
          child: SVGAEasyPlayer(
            resUrl: imageUrl,
            fit: BoxFit.cover,
          ),
        )
            : Image.network(
          imageUrl,
          width: width * 0.55,
          height: width * 0.34,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            return const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 82,
            );
          },
        ),
      ),
    );
  }
}

class _CoinStatusCard extends StatelessWidget {
  final double width;
  final WithdrawController controller;

  const _CoinStatusCard({
    required this.width,
    required this.controller,
  });

  double _fixedProgress() {
    final double targetCoins = controller.nextLevelNeedCoins <= 0
        ? 1.0
        : controller.nextLevelNeedCoins.toDouble();

    final double remainingCoins = max(
      controller.remainingCoinsForNextLevel.toDouble(),
      0.0,
    );

    final double calculatedProgress = 1.0 - (remainingCoins / targetCoins);

    if (calculatedProgress.isNaN || calculatedProgress.isInfinite) {
      return 0.0;
    }

    return calculatedProgress.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _fixedProgress();
    final int percent = (progress * 100).clamp(0, 100).toInt();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(width * 0.042),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xff8A4CF7).withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xffffd86f),
                  Color(0xffff9d2e),
                ],
              ),
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),

          SizedBox(width: width * 0.035),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ('My Coins').appTr,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xff81758f),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  controller.formatLevelCoins(controller.myLevelCoins),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    color: const Color(0xff2d2340),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xff8A4CF7).withOpacity(0.10),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '$percent%',
              style: GoogleFonts.poppins(
                color: const Color(0xff8A4CF7),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllLevelsSection extends StatelessWidget {
  final WithdrawController controller;
  final double width;

  const _AllLevelsSection({
    required this.controller,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final levels = controller.sortedLevelList;

    if (levels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ('Level Rewards').appTr,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xff2d2340),
          ),
        ),

        const SizedBox(height: 14),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: levels.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = levels[index];

            final needCoins = int.tryParse('${item['coins'] ?? 0}') ?? 0;

            final isCurrent = controller.currentLevelData?['id'] == item['id'];

            final imageUrl = controller.levelImageUrl(
              item['image']?.toString(),
            );

            return _SmallLevelTile(
              width: width,
              imageUrl: imageUrl,
              title: ('LV ${item['start']} - ${item['end']}').appTr,
              coins: needCoins <= 0
                  ? 'Coming Soon': '${controller.formatLevelCoins(needCoins)} coins',
              isCurrent: isCurrent,
            );
          },
        ),
      ],
    );
  }
}

class _SmallLevelTile extends StatelessWidget {
  final double width;
  final String imageUrl;
  final String title;
  final String coins;
  final bool isCurrent;

  const _SmallLevelTile({
    required this.width,
    required this.imageUrl,
    required this.title,
    required this.coins,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final isSvga = imageUrl.toLowerCase().endsWith('.svga');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xff8A4CF7) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? const Color(0xff8A4CF7)
              : const Color(0xff8A4CF7).withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: kWeight * 0.33,
            height: kWeight * 0.07,
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl.isEmpty
                  ? Icon(
                Icons.workspace_premium_rounded,
                color:
                isCurrent ? Colors.white : const Color(0xff8A4CF7),
              )
                  : isSvga
                  ? SVGAEasyPlayer(
                resUrl: imageUrl,
                fit: BoxFit.cover,
              )
                  : Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    Icons.workspace_premium_rounded,
                    color: isCurrent
                        ? Colors.white
                        : const Color(0xff8A4CF7),
                  );
                },
              ),
            ),
          ),

          SizedBox(width: width * 0.035),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: isCurrent ? Colors.white : const Color(0xff2d2340),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  coins,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isCurrent
                        ? Colors.white.withOpacity(0.88)
                        : const Color(0xff776b86),
                  ),
                ),
              ],
            ),
          ),

          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                ('Current').appTr,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UpgradeItem extends StatelessWidget {
  final String number;
  final String title;
  final String text;

  const _UpgradeItem({
    required this.number,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xff8A4CF7).withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: (w * 0.075).clamp(28.0, 34.0),
            height: (w * 0.075).clamp(28.0, 34.0),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xffffd5e3),
                  Color(0xffff8fbd),
                ],
              ),
            ),
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xfff25a8f),
              ),
            ),
          ),

          SizedBox(width: w * 0.035),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xff333333),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xff777777),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelLoadingView extends StatelessWidget {
  final double width;

  const _LevelLoadingView({
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(width * 0.05),
      children: [
        _shimmerBox(height: width * 0.82),
        const SizedBox(height: 18),
        _shimmerBox(height: 76),
        const SizedBox(height: 28),
        _shimmerBox(height: 22, width: width * 0.52),
        const SizedBox(height: 16),
        _shimmerBox(height: 90),
        const SizedBox(height: 12),
        _shimmerBox(height: 90),
        const SizedBox(height: 12),
        _shimmerBox(height: 90),
      ],
    );
  }

  Widget _shimmerBox({
    required double height,
    double? width,
  }) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xffeee7f8),
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }
}