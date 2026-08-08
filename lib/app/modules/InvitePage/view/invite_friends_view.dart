import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../invite_controller/invite_controller.dart';
import 'invite_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class InviteFriendsView extends StatelessWidget {
  const InviteFriendsView({super.key});

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
                InviteHeader(title: ('My Invited Friends').appTr, onBack: () => Get.back()),
                Expanded(
                  child: Obx(() {
                    final loading = c.friendsLoading.value && c.friends.isEmpty;
                    if (loading) return const Center(child: CircularProgressIndicator(color: kInviteColor1));

                    if (!c.isLoggedIn) {
                      return  Padding(
                        padding: EdgeInsets.all(16),
                        child: InviteEmptyCard(
                          icon: Icons.lock_rounded,
                          title: ('Login Required').appTr,
                          subtitle: ('Please login first to see your invited friends.').appTr,
                        ),
                      );
                    }

                    if (c.friends.isEmpty) {
                      return RefreshIndicator(
                        color: kInviteColor1,
                        onRefresh: () => c.fetchMyFriends(refresh: true),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: EdgeInsets.all(InviteUi.s(context, 14)),
                          children:  [
                            InviteEmptyCard(
                              icon: Icons.people_alt_rounded,
                              title: ('No invited friend found').appTr,
                              subtitle: ('Share your invite link and your invited friends will show here.').appTr,
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: kInviteColor1,
                      onRefresh: () => c.fetchMyFriends(refresh: true),
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: EdgeInsets.fromLTRB(
                          InviteUi.s(context, 14),
                          InviteUi.s(context, 4),
                          InviteUi.s(context, 14),
                          InviteUi.s(context, 24),
                        ),
                        itemCount: c.friends.length + 1,
                        separatorBuilder: (_, __) => SizedBox(height: InviteUi.s(context, 10)),
                        itemBuilder: (context, index) {
                          if (index == c.friends.length) {
                            if (!c.hasMoreFriends) return SizedBox(height: InviteUi.s(context, 6));
                            return InvitePrimaryButton(
                              title: ('Load More').appTr,
                              icon: Icons.keyboard_arrow_down_rounded,
                              loading: c.friendsLoading.value,
                              onTap: () => c.fetchMyFriends(refresh: false),
                            );
                          }
                          return _FriendCard(friend: c.friends[index]);
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

class _FriendCard extends StatelessWidget {
  const _FriendCard({required this.friend});

  final InviteFriend friend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(InviteUi.s(context, 12)),
      decoration: InviteUi.cardDecoration(context),
      child: Row(
        children: [
          _Avatar(friend: friend),
          SizedBox(width: InviteUi.s(context, 11)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: InviteUi.font(context, size: 13, weight: FontWeight.w900)),
                SizedBox(height: InviteUi.s(context, 3)),
                Text(
                  friend.username.isNotEmpty
                      ? '@${friend.username}'
                      : (friend.email.isNotEmpty
                      ? friend.email
                      : AppLocalizer.friendIdText(friend.id)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: InviteUi.font(context, size: 10, weight: FontWeight.w600, color: const Color(0xFF7C8092)),
                ),
                SizedBox(height: InviteUi.s(context, 7)),
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: const Color(0xFF989CAF), size: InviteUi.s(context, 13)),
                    SizedBox(width: InviteUi.s(context, 4)),
                    Expanded(
                      child: Text(
                        friend.createdAt.isEmpty ? ('Joined date not found').appTr: friend.createdAt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: InviteUi.font(context, size: 8.8, weight: FontWeight.w600, color: const Color(0xFF989CAF)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: InviteUi.s(context, 8)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: InviteUi.s(context, 9), vertical: InviteUi.s(context, 6)),
            decoration: BoxDecoration(
              color: friend.firstLiveDone ? const Color(0xFFE9F8EF) : const Color(0xFFFFF0E8),
              borderRadius: BorderRadius.circular(InviteUi.s(context, 14)),
            ),
            child: Text(
              friend.firstLiveDone ? ('Qualified').appTr: ('Pending').appTr,
              style: InviteUi.font(
                context,
                size: 8.6,
                weight: FontWeight.w900,
                color: friend.firstLiveDone ? Colors.green : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.friend});

  final InviteFriend friend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: InviteUi.s(context, 50),
      height: InviteUi.s(context, 50),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [kInviteColor1, kInviteColor2]),
        boxShadow: [BoxShadow(color: kInviteColor1.withOpacity(.16), blurRadius: 14, offset: const Offset(0, 7))],
      ),
      padding: EdgeInsets.all(InviteUi.s(context, 2)),
      child: ClipOval(
        child: friend.profileImage.isNotEmpty
            ? Image.network(friend.profileImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _FallbackAvatar(friend: friend))
            : _FallbackAvatar(friend: friend),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.friend});

  final InviteFriend friend;

  @override
  Widget build(BuildContext context) {
    final letter = friend.name.trim().isEmpty ? 'U': friend.name.trim()[0].toUpperCase();
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(letter, style: InviteUi.font(context, size: 18, weight: FontWeight.w900, color: kInviteColor1)),
    );
  }
}
