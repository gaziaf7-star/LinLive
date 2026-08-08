import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/modules/appmenu/views/widgets/imageColor.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../constants/image_helper.dart';
import '../controllers/notification_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class Panalnotification extends StatelessWidget {
  const Panalnotification({super.key});

  NotificationController get _controller {
    if (Get.isRegistered<NotificationController>()) {
      return Get.find<NotificationController>();
    }
    return Get.put(NotificationController());
  }

  @override
  Widget build(BuildContext context) {
    final NotificationController controller = _controller;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor:kAppbarColor,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: Color(0xFF20242F),
          ),
        ),
        title: Obx(() {
          final int unread = controller.unreadCount;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                ('Official Notification').appTr,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF171A23),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unread > 0) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF02D55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          );
        }),
        actions: <Widget>[
          Obx(() {
            if (controller.unreadCount <= 0 || controller.isLoading.value) {
              return const SizedBox.shrink();
            }
            return TextButton(
              onPressed: controller.markAllVisibleAsRead,
              child: Text(
                ('Mark all read').appTr,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2563EB),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8EAF0)),
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.notificationListData.isEmpty) {
          return const _NotificationLoadingList();
        }

        if (controller.hasError.value &&
            controller.notificationListData.isEmpty) {
          return _NotificationErrorState(
            message: controller.errorMessage.value,
            onRetry: controller.showNotificationData,
          );
        }

        if (controller.notificationListData.isEmpty) {
          return _NotificationEmptyState(
            onRefresh: controller.refreshNotifications,
          );
        }

        return RefreshIndicator(
          color: const Color(0xFFF02D55),
          backgroundColor: Colors.white,
          onRefresh: controller.refreshNotifications,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            itemCount: controller.notificationListData.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final Map<String, dynamic> notification =
              controller.notificationListData[index];
              return _NotificationCard(
                notification: notification,
                onTap: () {
                  final int id = _toInt(
                    notification['id'] ?? notification['notification_id'],
                  );
                  if (id > 0) {
                    controller.markAsRead(id);
                  }
                },
              );
            },
          ),
        );
      }),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> sender = _asMap(notification['sender']);
    final Map<String, dynamic> notificationData = _asMap(
      notification['notification_data'] ?? notification['data'],
    );

    final bool isRead = _truthy(notification['is_read']);
    final String senderName = _firstText(<dynamic>[
      sender['name'],
      notification['sender_name'],
    ]);
    final String title = _firstText(<dynamic>[
      notification['title'],
      notificationData['title'],
      senderName,
      'LIN LIVE',
    ]);

    String body = _firstText(<dynamic>[
      notification['text'],
      notification['message'],
      notification['body'],
      notificationData['text'],
      notificationData['message'],
      notificationData['body'],
    ]);

    final String type = _firstText(<dynamic>[
      notification['type'],
      notificationData['notification_type'],
      notificationData['notice_type'],
    ]).toLowerCase();

    if (body.isEmpty && senderName.isNotEmpty && type.contains('live')) {
      body = '$senderName is now live! Tap to view!'.appTr;
    }
    if (body.isEmpty) {
      body = ('You have a new notification').appTr;
    }

    final String senderId = _firstText(<dynamic>[
      sender['user_id'],
      sender['id'],
      notification['sender_id'],
    ]);
    final String imageUrl = _notificationImage(notification, sender);
    final DateTime? createdAt = _parseDate(
      notification['created_at'] ??
          notification['sent_at'] ??
          notificationData['sent_at'],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFEFF5FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isRead
                  ? const Color(0xFFE8EAF0)
                  : const Color(0xFFD8E7FF),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withOpacity(isRead ? 0.035 : 0.055),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _NotificationAvatar(
                imageUrl: imageUrl,
                unread: !isRead,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF171A23),
                              fontSize: 13.2,
                              fontWeight:
                              isRead ? FontWeight.w700 : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!isRead) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1877F2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF5E6472),
                        fontSize: 11.5,
                        height: 1.38,
                        fontWeight:
                        isRead ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: <Widget>[
                        if (senderId.isNotEmpty) ...<Widget>[
                          Icon(
                            Icons.badge_outlined,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'ID: $senderId',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF858B98),
                                fontSize: 9.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _relativeTime(createdAt),
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF858B98),
                            fontSize: 9.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({
    required this.imageUrl,
    required this.unread,
  });

  final String imageUrl;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: unread
              ? const <Color>[Color(0xFF1877F2), Color(0xFF7C3AED)]
              : const <Color>[Color(0xFFE2E5EA), Color(0xFFF4F5F7)],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: imageUrl.isEmpty
              ? _fallbackAvatar()
              : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => _avatarShimmer(),
            errorWidget: (_, __, ___) => _fallbackAvatar(),
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFFF02D55),
      alignment: Alignment.center,
      child: const Icon(
        Icons.notifications_active_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Widget _avatarShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(color: Colors.white),
    );
  }
}

class _NotificationLoadingList extends StatelessWidget {
  const _NotificationLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFFE5E7EB),
          highlightColor: const Color(0xFFF8FAFC),
          child: Container(
            height: 104,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: const Color(0xFFF02D55),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(height: MediaQuery.sizeOf(context).height * .18),
          Center(
            child: Column(
              children: <Widget>[
                Container(
                  width: 92,
                  height: 92,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE9EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFFF02D55),
                    size: 46,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  ('No notifications yet').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF20242F),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  ('New updates will appear here.').appTr,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF858B98),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

class _NotificationErrorState extends StatelessWidget {
  const _NotificationErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function({bool refresh}) onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_rounded,
              color: Color(0xFFF02D55),
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              message.isEmpty ? 'Failed to load notifications'.appTr : message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: const Color(0xFF5E6472),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => onRetry(refresh: false),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(('Try again').appTr),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF02D55),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _firstText(List<dynamic> values) {
  for (final dynamic value in values) {
    final String text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _truthy(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final String text = value?.toString().trim().toLowerCase() ?? '';
  return text == '1' || text == 'true' || text == 'yes' || text == 'read';
}

String _notificationImage(
    Map<String, dynamic> notification,
    Map<String, dynamic> sender,
    ) {
  final String raw = _firstText(<dynamic>[
    notification['image_url'],
    notification['image'],
    sender['profile_image_url'],
    sender['profile_image'],
    sender['image'],
  ]);

  if (raw.isEmpty) return '';
  if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
  return ImageHelper.getImageUrl(raw);
}

DateTime? _parseDate(dynamic value) {
  final String text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return DateTime.tryParse(text)?.toLocal();
}

String _relativeTime(DateTime? date) {
  if (date == null) return '--';

  final Duration difference = DateTime.now().difference(date);
  if (difference.isNegative || difference.inSeconds < 10) return 'Just now'.appTr;
  if (difference.inMinutes < 1) return '${difference.inSeconds}s';
  if (difference.inHours < 1) return '${difference.inMinutes}m';
  if (difference.inDays < 1) return '${difference.inHours}h';
  if (difference.inDays < 7) return '${difference.inDays}d';

  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
