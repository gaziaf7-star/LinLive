import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

import '../../../../constants/image_helper.dart';
import '../../../services/cp_invite_model.dart';
import '../../Cp/controllers/cpinviteController.dart';
import '../../Cp/views/cpAcceptPage.dart';
import 'chat_controller.dart';
import 'chat_model.dart';
import 'chatpage_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class MessengerView extends StatelessWidget {
  MessengerView({super.key});

  final ChatController _chatController = Get.put(ChatController());
  final CpInviteController _cpController = Get.put(CpInviteController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffff8fb),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Icon(
            Icons.arrow_back,
            color: Colors.black,
            size: kHeight * 0.028,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        title: Text(
          ('Messages').appTr,
          style: GoogleFonts.poppins(
            fontSize: kHeight * 0.019,
            fontWeight: FontWeight.w600,
            color: const Color(0xff201d27),
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xffffeef7),
                Color(0xfff2ddff),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _cpController.fetchCpInvites();
        },
        child: Column(
          children: [
            const SizedBox(height: 12),

            _CpInviteSection(controller: _cpController),

            Expanded(
              child: StreamBuilder<List<Chat>>(
                stream: _chatController.chats,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final chats = snapshot.data ?? [];

                  if (chats.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children:  [
                        SizedBox(height: 90),
                        Center(
                          child: Text(
                            ('No messages yet').appTr,
                            style: TextStyle(
                              color: Color(0xff7c6f79),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];

                      String? otherUserId;
                      try {
                        otherUserId = chat.participants.firstWhere(
                              (id) => id != _chatController.currentUserId,
                        );
                      } catch (e) {
                        return const SizedBox.shrink();
                      }

                      if (otherUserId == null) {
                        return const SizedBox.shrink();
                      }

                      return _ChatTile(
                        chat: chat,
                        userId: otherUserId,
                        onTap: () => _openChat(chat, otherUserId!),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(Chat chat, String otherUserId) {
    final participantNames = chat.participantNames;
    final participantImages = chat.participantImages;

    Get.to(
          () => ChatPage(
        receiverId: otherUserId,
        receiverName: participantNames[otherUserId] ?? ('Unknown').appTr,
        receiverImage: participantImages[otherUserId] ?? '',
      ),
      transition: Transition.rightToLeftWithFade,
      duration: const Duration(milliseconds: 320),
    );
  }
}

class _CpInviteSection extends StatelessWidget {
  const _CpInviteSection({
    required this.controller,
  });

  final CpInviteController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final requests = controller.cpRequests
          .where((e) => e.isPending)
          .toList();

      if (controller.isLoading.value && requests.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: SizedBox(
              width: 23,
              height: 23,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
        );
      }

      if (requests.isEmpty) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xffff5d96),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  ('CP Requests').appTr,
                  style: TextStyle(
                    color: Color(0xff201d27),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  '${requests.length}',
                  style: const TextStyle(
                    color: Color(0xffff5d96),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 134,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _CpInviteMiniCard(request: requests[index]);
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    });
  }
}

class _CpInviteMiniCard extends StatelessWidget {
  const _CpInviteMiniCard({
    required this.request,
  });

  final CpInviteRequest request;

  @override
  Widget build(BuildContext context) {
    final partner = request.partnerUser;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Get.to(
              () => CpInviteAcceptPage(request: request),
          transition: Transition.rightToLeftWithFade,
          duration: const Duration(milliseconds: 340),
        );
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xfffff4fb),
              Color(0xffffd7ec),
              Color(0xfff1dcff),
            ],
          ),
          border: Border.all(
            color: Colors.white,
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffff5d96).withOpacity(.13),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -10,
              child: Icon(
                Icons.favorite_rounded,
                color: Colors.white.withOpacity(.55),
                size: 68,
              ),
            ),
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xffff74b5),
                          width: 1.7,
                        ),
                      ),
                      child: ClipOval(
                        child: _avatarImage(partner.profileImage),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xffff5d96),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ('Premium CP Invite').appTr,
                          style: TextStyle(
                            color: Color(0xffff5d96),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          partner.name.isEmpty ? ('Unknown').appTr: partner.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xff201d27),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ('ID: ${partner.userId}').appTr,
                          style: TextStyle(
                            color: const Color(0xff201d27).withOpacity(.58),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _smallBadge('${request.coin} coins'),
                            const SizedBox(width: 7),
                            _smallBadge(request.statusText),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xffb66aa4),
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.70),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xff9b3b83),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _avatarImage(String image) {
    if (image.isEmpty) {
      return Container(
        color: const Color(0xffffe2f0),
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xffff5d96),
          size: 30,
        ),
      );
    }

    return Image.network(
      ImageHelper.getImageUrl(image),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xffffe2f0),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xffff5d96),
            size: 30,
          ),
        );
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Chat chat;
  final String userId;
  final VoidCallback onTap;

  const _ChatTile({
    required this.chat,
    required this.userId,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ChatController chatController = Get.find<ChatController>();
    final participantNames = chat.participantNames;
    final participantImages = chat.participantImages;

    final unreadCount = chat.unreadCounts[chatController.currentUserId] ?? 0;

    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundImage: participantImages[userId] != null &&
                  participantImages[userId]!.isNotEmpty
                  ? NetworkImage(
                ImageHelper.getImageUrl(participantImages[userId]!),
              )
                  : null,
              radius: 24,
              child: participantImages[userId] == null ||
                  participantImages[userId]!.isEmpty
                  ? const Icon(Icons.person, size: 23)
                  : null,
            ),
            title: Text(
              participantNames[userId] ?? ('Unknown').appTr,
              style: const TextStyle(
                fontSize: 17,
                color: Color(0xff201d27),
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              chat.lastMessage,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(chat.lastMessageTime),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xffff5d96),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: Get.width * 0.16,
              right: Get.width * 0.04,
            ),
            child: Divider(
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(time);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return ('Just now').appTr;
    }
  }
}