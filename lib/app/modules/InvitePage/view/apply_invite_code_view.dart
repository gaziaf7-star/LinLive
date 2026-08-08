import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../invite_controller/invite_controller.dart';
import 'invite_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class ApplyInviteCodeView extends StatelessWidget {
  const ApplyInviteCodeView({super.key});

  InviteController get controller {
    if (Get.isRegistered<InviteController>()) {
      return Get.find<InviteController>();
    }
    return Get.put(InviteController());
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 650;
              final maxWidth = isTablet ? 520.0 : 460.0;

              return Stack(
                children: [
                  const _ApplyInviteBackground(),

                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: InviteHeader(
                                title: ('Apply Invite Code').appTr,
                                onBack: () => Get.back(),
                              ),
                            ),

                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  InviteUi.s(context, 14),
                                  InviteUi.s(context, 8),
                                  InviteUi.s(context, 14),
                                  InviteUi.s(context, 26),
                                ),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 450),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 22 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      const _VipInviteHeroCard(),

                                      SizedBox(height: InviteUi.s(context, 16)),

                                      _InviteCodeFormCard(controller: c),

                                      SizedBox(height: InviteUi.s(context, 15)),

                                      const _InviteRuleCard(),

                                      SizedBox(height: InviteUi.s(context, 14)),

                                      InviteEmptyCard(
                                        icon: Icons.info_outline_rounded,
                                        title: ('Important Note').appTr,
                                        subtitle:
                                        ('If registration already sent reffer_by, you do not need to apply code again.').appTr,
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
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ApplyInviteBackground extends StatelessWidget {
  const _ApplyInviteBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFF5F7),
                  Color(0xFFFFEEF2),
                  Color(0xFFFFFFFF),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        Positioned(
          top: -70,
          right: -70,
          child: _GlowCircle(
            size: InviteUi.s(context, 190),
            color: kInviteColor1.withOpacity(.18),
          ),
        ),

        Positioned(
          top: InviteUi.s(context, 190),
          left: -90,
          child: _GlowCircle(
            size: InviteUi.s(context, 170),
            color: kInviteColor2.withOpacity(.14),
          ),
        ),

        Positioned(
          bottom: -80,
          right: -60,
          child: _GlowCircle(
            size: InviteUi.s(context, 180),
            color: const Color(0xFFFFC947).withOpacity(.15),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 55,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _VipInviteHeroCard extends StatelessWidget {
  const _VipInviteHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(InviteUi.s(context, 18)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(InviteUi.s(context, 28)),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFD66B),
            Color(0xFFFF5C7C),
            Color(0xFFF80230),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: kInviteColor1.withOpacity(.28),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -18,
            child: Icon(
              Icons.stars_rounded,
              color: Colors.white.withOpacity(.12),
              size: InviteUi.s(context, 120),
            ),
          ),

          Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: InviteUi.s(context, 12),
                  vertical: InviteUi.s(context, 7),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(.24),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.workspace_premium_rounded,
                      color: const Color(0xFFFFF4B8),
                      size: InviteUi.s(context, 17),
                    ),
                    SizedBox(width: InviteUi.s(context, 6)),
                    Text(
                      ('VIP INVITE SYSTEM').appTr,
                      style: InviteUi.font(
                        context,
                        size: 10.5,
                        weight: FontWeight.w900,
                        color: Colors.white,

                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: InviteUi.s(context, 16)),
              Container(
                width: InviteUi.s(context, 66),
                height: InviteUi.s(context, 66),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(.28),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 18,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.redeem_rounded,
                  color: Colors.white,
                  size: InviteUi.s(context, 34),
                ),
              ),
              SizedBox(height: InviteUi.s(context, 13)),

              Text(
                ('Got an invite code?').appTr,
                textAlign: TextAlign.center,
                style: InviteUi.font(
                  context,
                  size: 22,
                  weight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),

              SizedBox(height: InviteUi.s(context, 7)),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: InviteUi.s(context, 12),
                ),
                child: Text(
                  ('Enter your friend invite code and unlock your reward connection.').appTr,
                  textAlign: TextAlign.center,
                  style: InviteUi.font(
                    context,
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: Colors.white.withOpacity(.90),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteCodeFormCard extends StatelessWidget {
  final InviteController controller;

  const _InviteCodeFormCard({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(InviteUi.s(context, 16)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(InviteUi.s(context, 24)),
        border: Border.all(
          color: Colors.white,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDF1640).withOpacity(.09),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SmallIconBox(
                icon: Icons.confirmation_num_rounded,
                color: kInviteColor1,
              ),
              SizedBox(width: InviteUi.s(context, 9)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ('Invite Code').appTr,
                      style: InviteUi.font(
                        context,
                        size: 13,
                        weight: FontWeight.w900,
                        color: const Color(0xFF171827),
                      ),
                    ),
                    SizedBox(height: InviteUi.s(context, 2)),
                    Text(
                      ('Paste or type your invite code').appTr,
                      style: InviteUi.font(
                        context,
                        size: 10.5,
                        weight: FontWeight.w600,
                        color: const Color(0xFF9396A6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: InviteUi.s(context, 13)),

          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7F8),
              borderRadius: BorderRadius.circular(InviteUi.s(context, 18)),
              border: Border.all(
                color: const Color(0xFFFFDCE4),
              ),
            ),
            child: TextField(
              controller: controller.codeController,
              textInputAction: TextInputAction.done,
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
              cursorColor: kInviteColor1,
              decoration: InputDecoration(
                hintText: ('Enter invite code').appTr,
                hintStyle: InviteUi.font(
                  context,
                  size: 12,
                  weight: FontWeight.w700,
                  color: const Color(0xFFA1A4B3),
                ),
                prefixIcon: Icon(
                  Icons.vpn_key_rounded,
                  color: kInviteColor1,
                  size: InviteUi.s(context, 21),
                ),
                suffixIcon: IconButton(
                  onPressed: () => controller.codeController.clear(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: const Color(0xFF9EA1AF),
                    size: InviteUi.s(context, 19),
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: InviteUi.s(context, 14),
                  vertical: InviteUi.s(context, 15),
                ),
                border: InputBorder.none,
              ),
              style: InviteUi.font(
                context,
                size: 14,
                weight: FontWeight.w900,
                color: const Color(0xFF171827),

              ),
            ),
          ),

          SizedBox(height: InviteUi.s(context, 14)),

          Obx(() {
            // Read Rx values directly inside Obx. If they are first read only
            // inside LayoutBuilder, GetX cannot track them and throws
            // "improper use of GetX/Obx".
            final bool validating = controller.validateCodeLoading.value;
            final bool applying = controller.applyCodeLoading.value;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 330;

                if (isSmall) {
                  return Column(
                    children: [
                      InvitePrimaryButton(
                        title: ('Validate').appTr,
                        icon: Icons.verified_rounded,
                        backgroundColor: const Color(0xFFFFE9EE),
                        foregroundColor: kInviteColor1,
                        loading: validating,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          controller.validateInviteCode(
                            controller.codeController.text,
                          );
                        },
                      ),
                      SizedBox(height: InviteUi.s(context, 10)),
                      InvitePrimaryButton(
                        title: ('Apply Code').appTr,
                        icon: Icons.check_circle_rounded,
                        loading: applying,
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          final ok = await controller.applyInviteCode();
                          if (ok) Get.back();
                        },
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: InvitePrimaryButton(
                        title: ('Validate').appTr,
                        icon: Icons.verified_rounded,
                        backgroundColor: const Color(0xFFFFE9EE),
                        foregroundColor: kInviteColor1,
                        loading: validating,
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          controller.validateInviteCode(
                            controller.codeController.text,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: InviteUi.s(context, 10)),
                    Expanded(
                      child: InvitePrimaryButton(
                        title: ('Apply Code').appTr,
                        icon: Icons.check_circle_rounded,
                        loading: applying,
                        onTap: () async {
                          FocusScope.of(context).unfocus();
                          final ok = await controller.applyInviteCode();
                          if (ok) Get.back();
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

class _InviteRuleCard extends StatelessWidget {
  const _InviteRuleCard();

  @override
  Widget build(BuildContext context) {
    final items = [
      _RuleItem(
        icon: Icons.person_add_alt_1_rounded,
        title: ('One account').appTr,
        subtitle: ('One invite only').appTr,
      ),
      _RuleItem(
        icon: Icons.shield_rounded,
        title: ('Secure reward').appTr,
        subtitle: ('Duplicate blocked').appTr,
      ),
      _RuleItem(
        icon: Icons.bolt_rounded,
        title: ('Fast apply').appTr,
        subtitle: ('Instant check').appTr,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(InviteUi.s(context, 13)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.78),
        borderRadius: BorderRadius.circular(InviteUi.s(context, 22)),
        border: Border.all(color: Colors.white),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final small = constraints.maxWidth < 360;

          if (small) {
            return Column(
              children: items
                  .map(
                    (item) => Padding(
                  padding: EdgeInsets.only(bottom: InviteUi.s(context, 9)),
                  child: item,
                ),
              )
                  .toList(),
            );
          }

          return Row(
            children: [
              Expanded(child: items[0]),
              SizedBox(width: InviteUi.s(context, 8)),
              Expanded(child: items[1]),
              SizedBox(width: InviteUi.s(context, 8)),
              Expanded(child: items[2]),
            ],
          );
        },
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _RuleItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: InviteUi.s(context, 8),
        vertical: InviteUi.s(context, 10),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F8),
        borderRadius: BorderRadius.circular(InviteUi.s(context, 16)),
        border: Border.all(color: const Color(0xFFFFE1E8)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: kInviteColor1,
            size: InviteUi.s(context, 20),
          ),
          SizedBox(height: InviteUi.s(context, 6)),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: InviteUi.font(
              context,
              size: 10.5,
              weight: FontWeight.w900,
              color: const Color(0xFF242533),
            ),
          ),
          SizedBox(height: InviteUi.s(context, 2)),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: InviteUi.font(
              context,
              size: 9.5,
              weight: FontWeight.w700,
              color: const Color(0xFF9A9DAA),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SmallIconBox({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: InviteUi.s(context, 38),
      height: InviteUi.s(context, 38),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(InviteUi.s(context, 13)),
      ),
      child: Icon(
        icon,
        color: color,
        size: InviteUi.s(context, 21),
      ),
    );
  }
}