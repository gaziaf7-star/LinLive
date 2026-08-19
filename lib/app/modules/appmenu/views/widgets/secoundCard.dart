import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/modules/Cp/views/cp_view.dart';
import 'package:meetlivepro/app/modules/Famaily/view/family_home_api_page.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/managerDashbord.dart';
import 'package:meetlivepro/constants/constants.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

Widget secoundPremiumShortcutMenu({
  required double kHeight,
  required double kWeight,
}) {
  return Obx(() {
    AppLanguageController.to.currentLocaleKey.value;

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

  String get _userType =>
      authController.userProfile.value.user?.userType
          ?.toString()
          .trim()
          .toLowerCase() ??
          '';

  void _openDashboard({
    required String title,
    required String target,
  }) {
    Get.to(
          () => ManagerDashboardWebViewPage(
        title: title,
        target: target,
      ),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String userType = _userType;
    final bool isManager = userType == 'manager';
    final bool isSuperAdmin = userType == 'super_admin';
    final bool isBdAdmin = userType == 'bd_admin';
    final bool isBd = userType == 'bd';

    final items = <_PremiumItem>[
      _PremiumItem(
        title: 'Earnings'.appTr,
        image: 'assets/images/rechargeIcon.png',
        fallbackIcon: Icons.monetization_on_rounded,
        tileColor: const Color(0xFFFFF1DE),
        onTap: () {
          // Old code only referenced the function and did not call it.
          homeController.showEarningData();
        },
      ),
      if (isManager)
        _PremiumItem(
          title: 'Manager'.appTr,
          image: 'assets/newaudio/manager.png',
          fallbackIcon: Icons.admin_panel_settings_rounded,
          tileColor: const Color(0xFFEAF1FF),
          onTap: () {
            _openDashboard(
              title: 'Manager Dashboard'.appTr,
              target: 'manager_dashboard',
            );
          },
        ),
      if (isSuperAdmin)
        _PremiumItem(
          title: 'Super Admin'.appTr,
          image: 'assets/newaudio/super.png',
          fallbackIcon: Icons.workspace_premium_rounded,
          tileColor: const Color(0xFFF2ECFF),
          onTap: () {
            _openDashboard(
              title: 'Super Admin Dashboard'.appTr,
              target: 'super_admin_dashboard',
            );
          },
        ),
      if (isBdAdmin)
        _PremiumItem(
          title: 'BD Admin'.appTr,
          image: 'assets/newaudio/super.png',
          fallbackIcon: Icons.flag_circle_rounded,
          tileColor: const Color(0xFFE9F8EF),
          onTap: () {
            _openDashboard(
              title: 'BD Admin Dashboard'.appTr,
              target: 'bd_admin_dashboard',
            );
          },
        ),
      if (isBd)
        _PremiumItem(
          title: 'BD'.appTr,
          image: 'assets/newaudio/super.png',
          fallbackIcon: Icons.flag_circle_rounded,
          tileColor: const Color(0xFFE9F8EF),
          onTap: () {
            _openDashboard(
              title: 'BD Dashboard'.appTr,
              target: 'bd_dashboard',
            );
          },
        ),
      _PremiumItem(
        title: 'Family'.appTr,
        image: 'assets/images/family.png',
        fallbackIcon: Icons.groups_2_rounded,
        tileColor: const Color(0xFFFFF4E8),
        onTap: () {
          Get.to(
            FamilyHomeApiPage(),
            transition: Transition.rightToLeft,
          );
        },
      ),
      _PremiumItem(
        title: 'Couple'.appTr,
        image: 'assets/images/coupleICon.png',
        fallbackIcon: Icons.favorite_rounded,
        tileColor: const Color(0xFFFFECF4),
        onTap: () {
          Get.to(
            CpHomePage(),
            transition: Transition.rightToLeft,
          );
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
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
  bool _tapLocked = false;

  void _handleTap() {
    if (_tapLocked) return;

    _tapLocked = true;
    widget.item.onTap();

    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _tapLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double iconBox =
    (widget.kHeight * .060).clamp(48.0, 60.0).toDouble();
    final double iconSize = iconBox * .56;
    final Color tileColor = widget.item.tileColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (!_tapLocked) {
          setState(() => _pressed = true);
        }
      },
      onTapCancel: () {
        if (mounted) setState(() => _pressed = false);
      },
      onTapUp: (_) {
        if (mounted) setState(() => _pressed = false);
        _handleTap();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        scale: _pressed ? .96 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
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
                    fontSize:
                    (widget.kHeight * .0142).clamp(11.0, 13.2).toDouble(),
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
