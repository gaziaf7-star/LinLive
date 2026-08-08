import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';

import '../invite_controller/invite_controller.dart';
import 'apply_invite_code_view.dart';
import 'invite_friends_view.dart';
import 'invite_reward_history_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
const Color kInviteColor1 = Color(0xFFF80230);
const Color kInviteColor2 = Color(0xFFFD375D);
const Color kInviteAppbarColor = Color(0xFFF43C5D);

const Color _kVipDark = Color(0xFF17051F);
const Color _kVipPurple = Color(0xFF3B1057);
const Color _kVipGold = Color(0xFFFFD36A);
const Color _kVipGold2 = Color(0xFFFFA928);
const Color _kWhatsApp = Color(0xFF20C463);

class InviteEarnPage extends StatelessWidget {
  const InviteEarnPage({super.key});

  InviteController get controller {
    if (Get.isRegistered<InviteController>()) return Get.find<InviteController>();
    return Get.put(InviteController());
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F8),
      body: SafeArea(
        child: Stack(
          children: [
            const _PremiumPageBackground(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: RefreshIndicator(
                  color: kInviteColor1,
                  backgroundColor: Colors.white,
                  onRefresh: () => c.refreshInviteSystem(silent: false),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: InviteUi.s(context, 30)),
                    child: Obx(() {
                      final loading = c.inviteHomeLoading.value && c.activeMilestones.isEmpty;

                      if (loading) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InviteHeader(title: ('VIP Invite Club').appTr, onBack: () => Get.back()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: InviteUi.s(context, 14)),
                              child: const _InviteVipShimmer(),
                            ),
                          ],
                        );
                      }

                      final setting = c.activeSetting;
                      final stats = c.inviteHome.value.stats;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InviteHeader(title: ('VIP Invite Club').appTr, onBack: () => Get.back()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: InviteUi.s(context, 14)),
                            child: Column(
                              children: [
                                _InviteHeroCard(setting: setting, controller: c),
                                SizedBox(height: InviteUi.s(context, 14)),
                                _StatsGrid(stats: stats),
                                SizedBox(height: InviteUi.s(context, 14)),
                                _NextRewardCard(controller: c),
                                SizedBox(height: InviteUi.s(context, 16)),
                                _ActionGrid(controller: c),
                                SizedBox(height: InviteUi.s(context, 18)),
                                InviteSectionTitle(title: setting.howItWorksTitle.isEmpty ? ('How It Works').appTr: setting.howItWorksTitle),
                                SizedBox(height: InviteUi.s(context, 10)),
                                const _HowItWorksCard(),
                                SizedBox(height: InviteUi.s(context, 18)),
                                Row(
                                  children: [
                                    Expanded(child: InviteSectionTitle(title: ('VIP Rewards You Can Earn').appTr)),
                                    if (c.rewardListLoading.value)
                                      SizedBox(
                                        width: InviteUi.s(context, 16),
                                        height: InviteUi.s(context, 16),
                                        child: const CircularProgressIndicator(strokeWidth: 2, color: kInviteColor1),
                                      ),
                                  ],
                                ),
                                SizedBox(height: InviteUi.s(context, 12)),
                                _MilestoneWrap(
                                  milestones: c.activeMilestones,
                                  controller: c,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
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

class _PremiumPageBackground extends StatelessWidget {
  const _PremiumPageBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFFFFF7F8)),
        Container(
          height: InviteUi.s(context, 250),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kVipDark, _kVipPurple, kInviteColor1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Positioned(
          top: InviteUi.s(context, 28),
          right: InviteUi.s(context, -42),
          child: _GlowCircle(size: InviteUi.s(context, 150), color: Colors.white.withOpacity(.10)),
        ),
        Positioned(
          top: InviteUi.s(context, 145),
          left: InviteUi.s(context, -55),
          child: _GlowCircle(size: InviteUi.s(context, 130), color: _kVipGold.withOpacity(.16)),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}

class _InviteHeroCard extends StatelessWidget {
  const _InviteHeroCard({required this.setting, required this.controller});

  final InviteSetting setting;
  final InviteController controller;

  @override
  Widget build(BuildContext context) {
    final title = setting.title.trim().isEmpty
        ? 'Invite Friends. Earn Rewards.'.appTr
        : setting.title.trim().appTr;
    final subtitle = setting.subtitle.trim().isEmpty
        ? 'Share your VIP invite link and unlock rewards smoothly.'.appTr
        : setting.subtitle.trim().appTr;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(InviteUi.s(context, 2)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(InviteUi.s(context, 32)),
        gradient: const LinearGradient(colors: [_kVipGold, kInviteColor2, _kVipPurple], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [
          BoxShadow(color: kInviteColor1.withOpacity(.25), blurRadius: 34, offset: const Offset(0, 18)),
          BoxShadow(color: _kVipGold.withOpacity(.15), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          InviteUi.s(context, 18),
          InviteUi.s(context, 18),
          InviteUi.s(context, 18),
          InviteUi.s(context, 16),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(InviteUi.s(context, 30)),
          gradient: const LinearGradient(
            colors: [_kVipDark, Color(0xFF2B0A43), kInviteColor1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: InviteUi.s(context, -22),
              top: InviteUi.s(context, -18),
              child: Icon(Icons.workspace_premium_rounded, color: Colors.white.withOpacity(.08), size: InviteUi.s(context, 132)),
            ),
            Positioned(
              right: InviteUi.s(context, 12),
              top: InviteUi.s(context, 96),
              child: Icon(Icons.auto_awesome_rounded, color: _kVipGold.withOpacity(.33), size: InviteUi.s(context, 26)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _VipLogo(size: InviteUi.s(context, 52)),
                    SizedBox(width: InviteUi.s(context, 11)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: InviteUi.s(context, 6),
                            runSpacing: InviteUi.s(context, 4),
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _VipMiniBadge(text: ('VIP INVITE').appTr),
                              _VipMiniBadge(text: ('FAST REWARD').appTr, filled: false),
                            ],
                          ),
                          SizedBox(height: InviteUi.s(context, 7)),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: InviteUi.font(context, size: 20, weight: FontWeight.w900, color: Colors.white, height: 1.10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: InviteUi.s(context, 8)),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: InviteUi.font(context, size: 10.5, weight: FontWeight.w600, color: Colors.white.withOpacity(.82), height: 1.35),
                ),
                SizedBox(height: InviteUi.s(context, 16)),
                _LinkBox(
                  label: ('Your VIP Invite Link').appTr,
                  value: controller.inviteLink.isEmpty
                      ? 'Invite link loading...'.appTr
                      : controller.inviteLink,
                  icon: Icons.link_rounded,
                  onCopy: controller.copyInviteLink,
                ),
                SizedBox(height: InviteUi.s(context, 10)),
                _LinkBox(
                  label: ('Invite Code').appTr,
                  value: controller.inviteCode.isEmpty
                      ? 'Login to get code'.appTr
                      : controller.inviteCode,
                  icon: Icons.confirmation_num_rounded,
                  onCopy: controller.copyInviteCode,
                ),
                SizedBox(height: InviteUi.s(context, 14)),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 335;
                    final buttons = [
                      InvitePrimaryButton(
                        title: ('Copy Link').appTr,
                        icon: Icons.copy_rounded,
                        backgroundColor: Colors.white,
                        foregroundColor: kInviteColor1,
                        onTap: controller.copyInviteLink,
                      ),
                      InvitePrimaryButton(
                        title: ('WhatsApp').appTr,
                        icon: Icons.chat_bubble_rounded,
                        backgroundColor: _kWhatsApp,
                        foregroundColor: Colors.white,
                        borderColor: Colors.white.withOpacity(.20),
                        onTap: controller.shareInviteToWhatsApp,
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children: [
                          buttons[0],
                          SizedBox(height: InviteUi.s(context, 9)),
                          buttons[1],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: buttons[0]),
                        SizedBox(width: InviteUi.s(context, 10)),
                        Expanded(child: buttons[1]),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VipLogo extends StatelessWidget {
  const _VipLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_kVipGold, _kVipGold2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: _kVipGold.withOpacity(.36), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Container(
        margin: EdgeInsets.all(InviteUi.s(context, 4)),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF3B1351).withOpacity(.92),
          border: Border.all(color: Colors.white.withOpacity(.25)),
        ),
        child: Icon(Icons.workspace_premium_rounded, color: _kVipGold, size: InviteUi.s(context, 27)),
      ),
    );
  }
}

class _VipMiniBadge extends StatelessWidget {
  const _VipMiniBadge({required this.text, this.filled = true});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: InviteUi.s(context, 8), vertical: InviteUi.s(context, 4)),
      decoration: BoxDecoration(
        color: filled ? _kVipGold : Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(InviteUi.s(context, 30)),
        border: Border.all(color: filled ? _kVipGold : Colors.white.withOpacity(.22)),
      ),
      child: Text(
        text,
        style: InviteUi.font(
          context,
          size: 7.8,
          weight: FontWeight.w900,
          color: filled ? const Color(0xFF351006) : Colors.white,
        ),
      ),
    );
  }
}

class _LinkBox extends StatelessWidget {
  const _LinkBox({required this.label, required this.value, required this.icon, required this.onCopy});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: InviteUi.s(context, 12), vertical: InviteUi.s(context, 11)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.13),
        borderRadius: BorderRadius.circular(InviteUi.s(context, 17)),
        border: Border.all(color: Colors.white.withOpacity(.18)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: InviteUi.s(context, 34),
            height: InviteUi.s(context, 34),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(InviteUi.s(context, 13)),
            ),
            child: Icon(icon, color: _kVipGold, size: InviteUi.s(context, 18)),
          ),
          SizedBox(width: InviteUi.s(context, 9)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: InviteUi.font(context, size: 8.8, weight: FontWeight.w800, color: Colors.white.withOpacity(.70))),
                SizedBox(height: InviteUi.s(context, 2)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InviteUi.font(context, size: 11.2, weight: FontWeight.w900, color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(width: InviteUi.s(context, 8)),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(InviteUi.s(context, 14)),
            child: Container(
              padding: EdgeInsets.all(InviteUi.s(context, 8)),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.15), shape: BoxShape.circle),
              child: Icon(Icons.copy_rounded, color: Colors.white, size: InviteUi.s(context, 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final InviteStats stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(('Total Invites').appTr, stats.totalInvites.toString(), Icons.group_add_rounded, const LinearGradient(colors: [kInviteColor1, kInviteColor2])),
      _StatItem(('First Live').appTr, stats.completedFriends.toString(), Icons.live_tv_rounded, const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)])),
      _StatItem(('Earned Coins').appTr, stats.totalRewardCoins.toString(), Icons.monetization_on_rounded, const LinearGradient(colors: [_kVipGold2, _kVipGold])),
      _StatItem(('Pending').appTr, stats.pendingFriends.toString(), Icons.hourglass_bottom_rounded, const LinearGradient(colors: [Color(0xFF00C6FF), Color(0xFF0072FF)])),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = InviteUi.s(context, 9);
        final crossAxisCount = constraints.maxWidth < 430 ? 2 : 4;
        final itemWidth = (constraints.maxWidth - (gap * (crossAxisCount - 1))) / crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) => SizedBox(width: itemWidth, child: _StatCard(item: item))).toList(),
        );
      },
    );
  }
}

class _StatItem {
  _StatItem(this.label, this.value, this.icon, this.gradient);

  final String label;
  final String value;
  final IconData icon;
  final Gradient gradient;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: InviteUi.s(context, 13), horizontal: InviteUi.s(context, 10)),
      decoration: InviteUi.cardDecoration(context),
      child: Row(
        children: [
          Container(
            width: InviteUi.s(context, 38),
            height: InviteUi.s(context, 38),
            decoration: BoxDecoration(
              gradient: item.gradient,
              borderRadius: BorderRadius.circular(InviteUi.s(context, 15)),
              boxShadow: [BoxShadow(color: kInviteColor1.withOpacity(.10), blurRadius: 12, offset: const Offset(0, 7))],
            ),
            child: Icon(item.icon, color: Colors.white, size: InviteUi.s(context, 20)),
          ),
          SizedBox(width: InviteUi.s(context, 9)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 15, weight: FontWeight.w900)),
                SizedBox(height: InviteUi.s(context, 2)),
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 8.6, weight: FontWeight.w700, color: const Color(0xFF777C90))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextRewardCard extends StatelessWidget {
  const _NextRewardCard({required this.controller});

  final InviteController controller;

  @override
  Widget build(BuildContext context) {
    final milestone = controller.nextMilestone;
    if (milestone == null) return const SizedBox.shrink();

    final int remainingFriends = controller.remainingFriendsFor(milestone);
    final double progress = controller.progressFor(milestone);
    final bool completed = controller.isMilestoneCompleted(milestone);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(InviteUi.s(context, 2)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(InviteUi.s(context, 24)),
        gradient: LinearGradient(colors: [_kVipGold.withOpacity(.80), kInviteColor1.withOpacity(.85)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Container(
        padding: EdgeInsets.all(InviteUi.s(context, 15)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(InviteUi.s(context, 22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: InviteUi.s(context, 45),
                  height: InviteUi.s(context, 45),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_kVipGold2, _kVipGold]),
                    borderRadius: BorderRadius.circular(InviteUi.s(context, 16)),
                    boxShadow: [BoxShadow(color: _kVipGold.withOpacity(.28), blurRadius: 16, offset: const Offset(0, 7))],
                  ),
                  child: Icon(Icons.emoji_events_rounded, color: Colors.white, size: InviteUi.s(context, 25)),
                ),
                SizedBox(width: InviteUi.s(context, 10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(completed
                          ? 'VIP Reward Completed'.appTr
                          : 'Next VIP Reward'.appTr, style: InviteUi.font(context, size: 12.8, weight: FontWeight.w900)),
                      SizedBox(height: InviteUi.s(context, 3)),
                      Text(
                          '${milestone.title.appTr} • ${AppLocalizer.coinsText(milestone.rewardCoins)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 10.4, weight: FontWeight.w700, color: const Color(0xFF767A8E))),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: InviteUi.s(context, 10), vertical: InviteUi.s(context, 6)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEF2),
                    borderRadius: BorderRadius.circular(InviteUi.s(context, 18)),
                  ),
                  child: Text('${(progress * 100).round()}%', style: InviteUi.font(context, size: 12, weight: FontWeight.w900, color: kInviteColor1)),
                ),
              ],
            ),
            SizedBox(height: InviteUi.s(context, 12)),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: InviteUi.s(context, 9),
                backgroundColor: const Color(0xFFFFE4EA),
                valueColor: const AlwaysStoppedAnimation<Color>(kInviteColor1),
              ),
            ),
            SizedBox(height: InviteUi.s(context, 9)),
            Text(
              completed
                  ? 'You already completed this VIP milestone.'.appTr
                  : AppLocalizer.inviteFriendsRemaining(
                remainingFriends,
                toUnlock: true,
              ),
              style: InviteUi.font(context, size: 10, weight: FontWeight.w600, color: const Color(0xFF7A7F92)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.controller});

  final InviteController controller;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActionData(
        title: ('Friends').appTr,
        subtitle: ('Invited list').appTr,
        icon: Icons.people_alt_rounded,
        onTap: () {
          controller.fetchMyFriends(refresh: true);
          Get.to(() => const InviteFriendsView(), transition: Transition.rightToLeft);
        },
      ),
      _ActionData(
        title: ('Rewards').appTr,
        subtitle: ('Coin history').appTr,
        icon: Icons.account_balance_wallet_rounded,
        onTap: () {
          controller.fetchMyRewards(refresh: true);
          Get.to(() => const InviteRewardHistoryView(), transition: Transition.rightToLeft);
        },
      ),
      _ActionData(
        title: ('Apply').appTr,
        subtitle: ('Use code').appTr,
        icon: Icons.redeem_rounded,
        onTap: () => Get.to(() => const ApplyInviteCodeView(), transition: Transition.rightToLeft),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = InviteUi.s(context, 9);
        final oneColumn = constraints.maxWidth < 330;
        final itemWidth = oneColumn ? constraints.maxWidth : (constraints.maxWidth - (gap * 2)) / 3;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) => SizedBox(width: itemWidth, child: _ActionCard(data: item))).toList(),
        );
      },
    );
  }
}

class _ActionData {
  _ActionData({required this.title, required this.subtitle, required this.icon, required this.onTap});

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.data});

  final _ActionData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(InviteUi.s(context, 20)),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: InviteUi.s(context, 13), horizontal: InviteUi.s(context, 8)),
        decoration: InviteUi.cardDecoration(context),
        child: Column(
          children: [
            Container(
              width: InviteUi.s(context, 40),
              height: InviteUi.s(context, 40),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kInviteColor1, kInviteColor2]),
                borderRadius: BorderRadius.circular(InviteUi.s(context, 15)),
                boxShadow: [BoxShadow(color: kInviteColor1.withOpacity(.16), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Icon(data.icon, color: Colors.white, size: InviteUi.s(context, 21)),
            ),
            SizedBox(height: InviteUi.s(context, 8)),
            Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 11.5, weight: FontWeight.w900)),
            SizedBox(height: InviteUi.s(context, 2)),
            Text(data.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 8.5, weight: FontWeight.w600, color: const Color(0xFF85899B))),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    final items = [
      _HowItem('1', 'Share your VIP invite link with friends.'.appTr),
      _HowItem('2', 'Friend signs up using your invite code.'.appTr),
      _HowItem(
        '3',
        'Milestone completed and reward coins are added automatically.'.appTr,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(InviteUi.s(context, 14)),
      decoration: InviteUi.cardDecoration(context),
      child: Column(
        children: List.generate(items.length, (index) {
          return Padding(
            padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : InviteUi.s(context, 12)),
            child: Row(
              children: [
                Container(
                  width: InviteUi.s(context, 31),
                  height: InviteUi.s(context, 31),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [_kVipGold2, _kVipGold]),
                    boxShadow: [BoxShadow(color: _kVipGold.withOpacity(.22), blurRadius: 14, offset: const Offset(0, 7))],
                  ),
                  child: Text(items[index].number, style: InviteUi.font(context, size: 11, weight: FontWeight.w900, color: Colors.white)),
                ),
                SizedBox(width: InviteUi.s(context, 10)),
                Expanded(child: Text(items[index].text, style: InviteUi.font(context, size: 11, weight: FontWeight.w700, color: const Color(0xFF34384C), height: 1.25))),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _HowItem {
  _HowItem(this.number, this.text);

  final String number;
  final String text;
}

class _MilestoneWrap extends StatelessWidget {
  const _MilestoneWrap({
    required this.milestones,
    required this.controller,
  });

  final List<InviteMilestone> milestones;
  final InviteController controller;

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) {
      return  InviteEmptyCard(
        icon: Icons.card_giftcard_rounded,
        title: ('No reward milestone found').appTr,
        subtitle: ('Please check backend invite milestones.').appTr,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = InviteUi.s(context, 10);
        final count = constraints.maxWidth < 340 ? 1 : 2;
        final itemWidth = (constraints.maxWidth - (gap * (count - 1))) / count;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: milestones.map((milestone) => SizedBox(width: itemWidth, child: InviteMilestoneCard(
            milestone: milestone,
            controller: controller,
          ))).toList(),
        );
      },
    );
  }
}

class InviteMilestoneCard extends StatelessWidget {
  const InviteMilestoneCard({
    super.key,
    required this.milestone,
    required this.controller,
  });

  final InviteMilestone milestone;
  final InviteController controller;

  @override
  Widget build(BuildContext context) {
    final double progress = controller.progressFor(milestone);
    final int remainingFriends = controller.remainingFriendsFor(milestone);
    final bool completed = controller.isMilestoneCompleted(milestone);

    return Container(
      padding: EdgeInsets.all(InviteUi.s(context, 2)),
      decoration: BoxDecoration(
        gradient: completed
            ? const LinearGradient(colors: [Color(0xFF4ADE80), Color(0xFF16A34A)])
            : const LinearGradient(colors: [_kVipGold, Color(0xFFFFE8A8), kInviteColor2]),
        borderRadius: BorderRadius.circular(InviteUi.s(context, 24)),
      ),
      child: Container(
        padding: EdgeInsets.all(InviteUi.s(context, 13)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(InviteUi.s(context, 22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: InviteUi.s(context, 42),
                  height: InviteUi.s(context, 42),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFE5EA), Color(0xFFFFF3F5)]),
                    borderRadius: BorderRadius.circular(InviteUi.s(context, 15)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: milestone.iconImageUrl.isNotEmpty
                      ? Image.network(
                    milestone.iconImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(Icons.emoji_events_rounded, color: kInviteColor1, size: InviteUi.s(context, 23)),
                  )
                      : Icon(Icons.emoji_events_rounded, color: kInviteColor1, size: InviteUi.s(context, 23)),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: InviteUi.s(context, 8), vertical: InviteUi.s(context, 5)),
                  decoration: BoxDecoration(
                    color: completed
                        ? const Color(0xFFE9FBEF)
                        : const Color(0xFFFFEEF2),
                    borderRadius: BorderRadius.circular(InviteUi.s(context, 18)),
                  ),
                  child: Icon(
                    completed
                        ? Icons.verified_rounded
                        : Icons.lock_open_rounded,
                    color: completed ? Colors.green : kInviteColor1,
                    size: InviteUi.s(context, 16),
                  ),
                ),
              ],
            ),
            SizedBox(height: InviteUi.s(context, 12)),
            Text(milestone.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 12.5, weight: FontWeight.w900)),
            SizedBox(height: InviteUi.s(context, 5)),
            Text(
                AppLocalizer.coinsText(milestone.rewardCoins), maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 15, weight: FontWeight.w900, color: kInviteColor1)),
            SizedBox(height: InviteUi.s(context, 9)),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: InviteUi.s(context, 6),
                backgroundColor: const Color(0xFFFFE6EC),
                valueColor: AlwaysStoppedAnimation<Color>(
                  completed ? Colors.green : kInviteColor1,
                ),
              ),
            ),
            SizedBox(height: InviteUi.s(context, 7)),
            Text(
              completed
                  ? 'Completed'.appTr
                  : AppLocalizer.inviteFriendsRemaining(remainingFriends),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: InviteUi.font(context, size: 9.5, weight: FontWeight.w700, color: completed ? Colors.green : const Color(0xFF85899B)),
            ),
          ],
        ),
      ),
    );
  }
}

class InviteHeader extends StatelessWidget {
  const InviteHeader({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(InviteUi.s(context, 14), InviteUi.s(context, 8), InviteUi.s(context, 14), InviteUi.s(context, 12)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: InviteUi.s(context, 8), vertical: InviteUi.s(context, 7)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.95),
          borderRadius: BorderRadius.circular(InviteUi.s(context, 24)),
          border: Border.all(color: Colors.white.withOpacity(.55)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 20, offset: const Offset(0, 9))],
        ),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(InviteUi.s(context, 18)),
              onTap: onBack,
              child: Container(
                width: InviteUi.s(context, 34),
                height: InviteUi.s(context, 34),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2F5),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFFD7E1)),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded, size: InviteUi.s(context, 14), color: const Color(0xFF15182D)),
              ),
            ),
            SizedBox(width: InviteUi.s(context, 10)),
            Container(
              width: InviteUi.s(context, 30),
              height: InviteUi.s(context, 30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kVipGold2, _kVipGold]),
                borderRadius: BorderRadius.circular(InviteUi.s(context, 11)),
                boxShadow: [BoxShadow(color: _kVipGold.withOpacity(.28), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Icon(Icons.workspace_premium_rounded, color: Colors.white, size: InviteUi.s(context, 18)),
            ),
            SizedBox(width: InviteUi.s(context, 8)),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 16.3, weight: FontWeight.w900, color: const Color(0xFF141725))),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: InviteUi.s(context, 11), vertical: InviteUi.s(context, 6)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kInviteColor1, kInviteColor2]),
                borderRadius: BorderRadius.circular(InviteUi.s(context, 18)),
              ),
              child: Text(('LIN LIVE').appTr, style: InviteUi.font(context, size: 8, color: Colors.white, weight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

class InviteSectionTitle extends StatelessWidget {
  const InviteSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: InviteUi.s(context, 4),
            height: InviteUi.s(context, 17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kInviteColor1, kInviteColor2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(width: InviteUi.s(context, 8)),
          Flexible(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 15, weight: FontWeight.w900, color: const Color(0xFF141725))),
          ),
        ],
      ),
    );
  }
}

class InvitePrimaryButton extends StatelessWidget {
  const InvitePrimaryButton({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.backgroundColor = kInviteColor1,
    this.foregroundColor = Colors.white,
    this.borderColor,
    this.loading = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(InviteUi.s(context, 18)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: InviteUi.s(context, 45),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(InviteUi.s(context, 18)),
          border: borderColor == null ? null : Border.all(color: borderColor!),
          boxShadow: [BoxShadow(color: backgroundColor.withOpacity(.18), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: loading
            ? SizedBox(width: InviteUi.s(context, 18), height: InviteUi.s(context, 18), child: CircularProgressIndicator(strokeWidth: 2, color: foregroundColor))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foregroundColor, size: InviteUi.s(context, 17)),
            SizedBox(width: InviteUi.s(context, 6)),
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 11, weight: FontWeight.w900, color: foregroundColor))),
          ],
        ),
      ),
    );
  }
}

class InviteEmptyCard extends StatelessWidget {
  const InviteEmptyCard({super.key, required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(InviteUi.s(context, 24)),
      decoration: InviteUi.cardDecoration(context),
      child: Column(
        children: [
          Icon(icon, size: InviteUi.s(context, 42), color: kInviteColor1.withOpacity(.85)),
          SizedBox(height: InviteUi.s(context, 10)),
          Text(title, textAlign: TextAlign.center, style: InviteUi.font(context, size: 13, weight: FontWeight.w900)),
          SizedBox(height: InviteUi.s(context, 5)),
          Text(subtitle, textAlign: TextAlign.center, style: InviteUi.font(context, size: 10, weight: FontWeight.w600, color: const Color(0xFF85899B), height: 1.35)),
        ],
      ),
    );
  }
}

class _InviteVipShimmer extends StatelessWidget {
  const _InviteVipShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ShimmerCard(
          height: InviteUi.s(context, 280),
          radius: InviteUi.s(context, 30),
          child: Padding(
            padding: EdgeInsets.all(InviteUi.s(context, 18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _ShimmerBox(width: InviteUi.s(context, 54), height: InviteUi.s(context, 54), radius: InviteUi.s(context, 27)),
                    SizedBox(width: InviteUi.s(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ShimmerBox(width: double.infinity, height: InviteUi.s(context, 18), radius: 99),
                          SizedBox(height: InviteUi.s(context, 8)),
                          _ShimmerBox(width: InviteUi.s(context, 170), height: InviteUi.s(context, 12), radius: 99),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: InviteUi.s(context, 24)),
                _ShimmerBox(width: double.infinity, height: InviteUi.s(context, 56), radius: InviteUi.s(context, 18)),
                SizedBox(height: InviteUi.s(context, 10)),
                _ShimmerBox(width: double.infinity, height: InviteUi.s(context, 56), radius: InviteUi.s(context, 18)),
                const Spacer(),
                Row(
                  children: [
                    Expanded(child: _ShimmerBox(width: double.infinity, height: InviteUi.s(context, 45), radius: InviteUi.s(context, 18))),
                    SizedBox(width: InviteUi.s(context, 10)),
                    Expanded(child: _ShimmerBox(width: double.infinity, height: InviteUi.s(context, 45), radius: InviteUi.s(context, 18))),
                  ],
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: InviteUi.s(context, 14)),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = InviteUi.s(context, 9);
            final itemWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(
                4,
                    (_) => SizedBox(
                  width: itemWidth,
                  child: _ShimmerCard(
                    height: InviteUi.s(context, 66),
                    radius: InviteUi.s(context, 22),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
        ),
        SizedBox(height: InviteUi.s(context, 14)),
        _ShimmerCard(height: InviteUi.s(context, 120), radius: InviteUi.s(context, 24), child: const SizedBox.shrink()),
        SizedBox(height: InviteUi.s(context, 16)),
        Row(
          children: [
            Expanded(child: _ShimmerCard(height: InviteUi.s(context, 90), radius: InviteUi.s(context, 22), child: const SizedBox.shrink())),
            SizedBox(width: InviteUi.s(context, 9)),
            Expanded(child: _ShimmerCard(height: InviteUi.s(context, 90), radius: InviteUi.s(context, 22), child: const SizedBox.shrink())),
            SizedBox(width: InviteUi.s(context, 9)),
            Expanded(child: _ShimmerCard(height: InviteUi.s(context, 90), radius: InviteUi.s(context, 22), child: const SizedBox.shrink())),
          ],
        ),
      ],
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.height, required this.radius, required this.child});

  final double height;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _ShimmerBox(
      width: double.infinity,
      height: height,
      radius: radius,
      child: child,
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
    this.child,
  });

  final double width;
  final double height;
  final double radius;
  final Widget? child;

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1350))..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = const Color(0xFFFFE7ED);
    final highlight = Colors.white.withOpacity(.92);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final value = _animationController.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [base, highlight, base],
              stops: const [.18, .50, .82],
              begin: Alignment(-1.5 + (value * 3), -0.2),
              end: Alignment(-0.5 + (value * 3), 0.2),
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(color: Colors.white.withOpacity(.62)),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class InviteUi {
  static double s(BuildContext context, double value) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = (width / 390).clamp(.82, 1.16).toDouble();
    return value * scale;
  }

  static TextStyle font(
      BuildContext context, {
        required double size,
        Color color = const Color(0xFF111526),
        FontWeight weight = FontWeight.w600,
        double? height,
      }) {
    return GoogleFonts.poppins(
      fontSize: s(context, size),
      color: color,
      fontWeight: weight,
      height: height,
    );
  }

  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(s(context, 22)),
      boxShadow: [
        BoxShadow(color: kInviteColor1.withOpacity(.075), blurRadius: 22, offset: const Offset(0, 11)),
        BoxShadow(color: Colors.white.withOpacity(.75), blurRadius: 1, offset: const Offset(0, 0)),
      ],
      border: Border.all(color: const Color(0xFFFFE6EC)),
    );
  }
}
