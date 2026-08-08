import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../invite_controller/invite_controller.dart';
import 'invite_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class InviteRewardHistoryView extends StatelessWidget {
  const InviteRewardHistoryView({super.key});

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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                InviteHeader(title: ('Invite Reward History').appTr, onBack: () => Get.back()),
                Expanded(
                  child: Obx(() {
                    final loading = c.rewardHistoryLoading.value && c.rewardLogs.isEmpty;
                    if (loading) return const Center(child: CircularProgressIndicator(color: kInviteColor1));

                    if (!c.isLoggedIn) {
                      return  Padding(
                        padding: EdgeInsets.all(16),
                        child: InviteEmptyCard(
                          icon: Icons.lock_rounded,
                          title: ('Login Required').appTr,
                          subtitle: ('Please login first to see your invite reward history.').appTr,
                        ),
                      );
                    }

                    if (c.rewardLogs.isEmpty) {
                      return RefreshIndicator(
                        color: kInviteColor1,
                        onRefresh: () => c.fetchMyRewards(refresh: true),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: EdgeInsets.all(InviteUi.s(context, 14)),
                          children:  [
                            InviteEmptyCard(
                              icon: Icons.account_balance_wallet_rounded,
                              title: ('No reward history found').appTr,
                              subtitle: ('Your signup, first-live and milestone reward logs will show here.').appTr,
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: kInviteColor1,
                      onRefresh: () => c.fetchMyRewards(refresh: true),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: EdgeInsets.fromLTRB(
                          InviteUi.s(context, 14),
                          InviteUi.s(context, 4),
                          InviteUi.s(context, 14),
                          InviteUi.s(context, 24),
                        ),
                        itemCount: c.rewardLogs.length + 1,
                        separatorBuilder: (_, __) => SizedBox(height: InviteUi.s(context, 10)),
                        itemBuilder: (context, index) {
                          if (index == c.rewardLogs.length) {
                            if (!c.hasMoreRewards) return SizedBox(height: InviteUi.s(context, 6));
                            return InvitePrimaryButton(
                              title: ('Load More').appTr,
                              icon: Icons.keyboard_arrow_down_rounded,
                              loading: c.rewardHistoryLoading.value,
                              onTap: () => c.fetchMyRewards(refresh: false),
                            );
                          }
                          return _RewardLogCard(log: c.rewardLogs[index]);
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardLogCard extends StatelessWidget {
  const _RewardLogCard({required this.log});

  final InviteRewardLog log;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(InviteUi.s(context, 13)),
      decoration: InviteUi.cardDecoration(context),
      child: Row(
        children: [
          Container(
            width: InviteUi.s(context, 48),
            height: InviteUi.s(context, 48),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kInviteColor1, kInviteColor2]),
              borderRadius: BorderRadius.circular(InviteUi.s(context, 17)),
              boxShadow: [BoxShadow(color: kInviteColor1.withOpacity(.15), blurRadius: 13, offset: const Offset(0, 7))],
            ),
            child: Icon(_iconForType(log.type), color: Colors.white, size: InviteUi.s(context, 24)),
          ),
          SizedBox(width: InviteUi.s(context, 11)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.title.appTr, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 12.8, weight: FontWeight.w900)),
                SizedBox(height: InviteUi.s(context, 4)),
                Text(
                  log.friendName.isEmpty
                      ? _cleanType(log.type)
                      : '${_cleanType(log.type)} • ${log.friendName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InviteUi.font(context, size: 9.8, weight: FontWeight.w700, color: const Color(0xFF7C8092)),
                ),
                SizedBox(height: InviteUi.s(context, 6)),
                Text(
                  log.createdAt.isEmpty ? ('Date not found').appTr: log.createdAt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InviteUi.font(context, size: 8.7, weight: FontWeight.w600, color: const Color(0xFF989CAF)),
                ),
              ],
            ),
          ),
          SizedBox(width: InviteUi.s(context, 8)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${log.coins}', style: InviteUi.font(context, size: 16, weight: FontWeight.w900, color: kInviteColor1)),
              Text(('Coins').appTr, style: InviteUi.font(context, size: 8.5, weight: FontWeight.w700, color: const Color(0xFF85899B))),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('milestone')) return Icons.emoji_events_rounded;
    if (t.contains('live')) return Icons.live_tv_rounded;
    if (t.contains('signup') || t.contains('join')) return Icons.person_add_alt_1_rounded;
    return Icons.monetization_on_rounded;
  }

  String _cleanType(String type) {
    final clean = type.replaceAll('_', ' ').trim();
    if (clean.isEmpty) return 'Invite Reward'.appTr;
    final String title = clean.split(' ').map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
    return title.appTr;
  }
}
