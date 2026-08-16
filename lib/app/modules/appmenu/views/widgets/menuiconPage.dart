import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';


import 'package:meetlivepro/app/modules/withdraw/views/withdraw_view.dart';
import 'package:meetlivepro/constants/constants.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../../store/views/mall_category_page.dart';
import 'base_medal_view.dart';

Widget premiumShortcutMenu({
  required double kHeight,
  required double kWeight,
}) {
  return Obx(() {
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

    final bool isAgency = currentUser?.isAgencyAccount ?? false;
    final bool isHost = currentUser?.isHostAccount ?? false;
    final bool canShowCreator = isAgency || !isHost;

    final items = <_PremiumItem>[
      if (_canShowRecharge)
        _PremiumItem(
          title: 'Host Center'.appTr,
          image: 'assets/frame/retreat.png',
          fallbackIcon: Icons.account_balance_wallet_rounded,
          tileColor: const Color(0xFFF3EDFF),
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
        tileColor: const Color(0xFFEAF4FF),
        onTap: () {
          Get.to(
            MallCategoryPage(),
            transition: Transition.rightToLeft,
          );
        },
      ),
      if (canShowCreator)
        _PremiumItem(
          title: 'Creator'.appTr,
          image: 'assets/flaticons/government.png',
          fallbackIcon: Icons.verified_user_rounded,
          tileColor: const Color(0xFFFFF2E2),
          onTap: () {
            verifiedController.showNewAgenctList();
          },
        ),
      _PremiumItem(
        title: 'Badge'.appTr,
        image: 'assets/icons/verify.png',
        fallbackIcon: Icons.workspace_premium_rounded,
        tileColor: const Color(0xFFFFECF7),
        onTap: () {
          Get.to(
                () => const BaseMedalView(),
            transition: Transition.rightToLeft,
            duration: const Duration(milliseconds: 220),
          );
        },
      ),
    ];

    return _ShortcutRow(
      items: items,
      kHeight: kHeight,
      kWeight: kWeight,
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final List<_PremiumItem> items;
  final double kHeight;
  final double kWeight;

  const _ShortcutRow({
    required this.items,
    required this.kHeight,
    required this.kWeight,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Same 4-column slot system used by the second shortcut row.
        // This keeps every icon exactly under the matching column instead of
        // letting a shorter first row get pushed/compressed to the right.
        final double slotWidth = constraints.maxWidth / 4;
        final double rowHeight =
        (kHeight * .122).clamp(92.0, 112.0).toDouble();

        if (items.length <= 4) {
          return SizedBox(
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(items.length, (index) {
                return SizedBox(
                  width: slotWidth,
                  child: Center(
                    child: _ShortcutItem(
                      item: items[index],
                      kHeight: kHeight,
                    ),
                  ),
                );
              }),
            ),
          );
        }

        return SizedBox(
          height: rowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return SizedBox(
                width: slotWidth,
                child: Center(
                  child: _ShortcutItem(
                    item: items[index],
                    kHeight: kHeight,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ShortcutItem extends StatefulWidget {
  final _PremiumItem item;
  final double kHeight;

  const _ShortcutItem({
    required this.item,
    required this.kHeight,
  });

  @override
  State<_ShortcutItem> createState() => _ShortcutItemState();
}

class _ShortcutItemState extends State<_ShortcutItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final double iconBox = (widget.kHeight * .060).clamp(48.0, 60.0).toDouble();
    final double iconSize = iconBox * .56;
    final Color tileColor = widget.item.tileColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.item.onTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _pressed ? .96 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(iconBox * .30),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(.92),
                    tileColor,
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(.95),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: tileColor.withOpacity(.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Container(
                width: iconBox * .78,
                height: iconBox * .78,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(iconBox * .24),
                  color: tileColor.withOpacity(.35),
                ),
                alignment: Alignment.center,
                child: Image.asset(
                  widget.item.image,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    widget.item.fallbackIcon,
                    size: iconSize,
                    color: const Color(0xFF6A6E77),
                  ),
                ),
              ),
            ),
            SizedBox(height: widget.kHeight * .008),
            SizedBox(
              height: widget.kHeight * .036,
              child: Center(
                child: Text(
                  widget.item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2E2F33),
                    fontWeight: FontWeight.w500,
                    fontSize: (widget.kHeight * .0142).clamp(11.0, 13.2).toDouble(),
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumItem {
  final String title;
  final String image;
  final IconData fallbackIcon;
  final Color tileColor;
  final VoidCallback onTap;

  const _PremiumItem({
    required this.title,
    required this.image,
    required this.fallbackIcon,
    required this.tileColor,
    required this.onTap,
  });
}
