import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/constants/color_constants.dart';

import '../../../../constants/layout_constant.dart';
import '../controllers/notification_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class NotificationCardView extends StatelessWidget {
  const NotificationCardView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NotificationController());

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(
            child: _LightGlowBackground(),
          ),

          Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            if (controller.hasError.value) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      controller.errorMessage.value,
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: controller.refreshNotifications,
                      child:  Text(('Retry').appTr),
                    ),
                  ],
                ),
              );
            }

            if (controller.notificationListData.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ('No notifications yet').appTr,
                      style: GoogleFonts.lato(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ('You\'ll see notifications here when you receive them').appTr,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: controller.refreshNotifications,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.notificationListData.length,
                itemBuilder: (context, index) {
                  return _buildNotificationCard(
                    controller.notificationListData[index],
                    index,
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Notification Card
  // ─────────────────────────────────────────
  Widget _buildNotificationCard(dynamic notification, int index) {
    final sender = notification['sender'];
    final text = notification['text'] ?? 'No message';
    final createdAt = notification['created_at'] ?? '';
    final type = notification['type'] ?? 'general';
    final bool isRead =
        notification['is_read'] == true || notification['is_read'] == 1;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showNotificationDialog(notification),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isRead
              ? null
              : const Border(
              left: BorderSide(color: Color(0xFF7F77DD), width: 3)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + unread dot
              Stack(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: _getTypeColor(type),
                    backgroundImage:
                    (sender != null && sender['image'] != null)
                        ? NetworkImage(sender['image'])
                        : null,
                    child: (sender == null || sender['image'] == null)
                        ? Icon(_getTypeIcon(type),
                        color: Colors.white, size: 20)
                        : null,
                  ),
                  if (!isRead)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border:
                          Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Text area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            text,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.w600,
                              color: isRead
                                  ? Colors.grey[600]
                                  : Colors.black87,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateTime(createdAt),
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    if (sender != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            ('From: ${sender['name'] ?? 'Unknown'}').appTr,
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isRead)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                ('Read').appTr,
                                style: GoogleFonts.lato(
                                  color: Colors.green[700],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // 3-dot menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert,
                    color: Colors.grey[400], size: 20),
                itemBuilder: (context) => [
                  if (!isRead)
                     PopupMenuItem(
                      value: 'mark_read',
                      child: Row(
                        children: [
                          Icon(Icons.mark_email_read,
                              size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(('Mark as read').appTr),
                        ],
                      ),
                    ),
                   PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text(('Delete').appTr,
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  final ctrl = Get.find<NotificationController>();
                  final id =
                      int.tryParse(notification['id'].toString()) ?? 0;
                  if (value == 'mark_read') {
                    ctrl.markAsRead(id);
                  } else if (value == 'delete') {
                    ctrl.deleteNotification(id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Notification Dialog (Get.dialog)
  // ─────────────────────────────────────────
  void _showNotificationDialog(Map notification) {
    final type = notification['type'] ?? 'info';
    final text = notification['text'] ?? '';
    final sender = notification['sender'];
    final createdAt = notification['created_at'] ?? '';
    final bool isRead =
        notification['is_read'] == true || notification['is_read'] == 1;
    final int id =
        int.tryParse(notification['id'].toString()) ?? 0;
    final RxBool markedRead = isRead.obs;

    Get.dialog(
      Obx(
            () => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          insetPadding:  EdgeInsets.symmetric(
              horizontal: kWeight*0.06, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _getTypeColor(type),
                      backgroundImage: sender?['image'] != null
                          ? NetworkImage(sender!['image'])
                          : null,
                      child: sender?['image'] == null
                          ? Icon(_getTypeIcon(type),
                          color: Colors.white, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type == 'offer'
                                ? ('Special offer').appTr: type[0].toUpperCase() +
                                type.substring(1),
                            style: GoogleFonts.lato(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDateTime(createdAt),
                            style: GoogleFonts.lato(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.5),

              // Body
              ConstrainedBox(
                constraints:
                BoxConstraints(maxHeight: Get.height * 0.45),
                child: SingleChildScrollView(
                  padding:
                  const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (sender != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 9,
                                backgroundColor:
                                _getTypeColor(type),
                                backgroundImage:
                                sender['image'] != null
                                    ? NetworkImage(
                                    sender['image'])
                                    : null,
                                child: sender['image'] == null
                                    ? Icon(_getTypeIcon(type),
                                    size: 10,
                                    color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                ('From: ${sender['name'] ?? 'Unknown'}').appTr,
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        text,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          height: 1.7,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 0.5),

              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!markedRead.value) ...[
                      TextButton(
                        onPressed: () {
                          Get.find<NotificationController>()
                              .markAsRead(id);
                          markedRead.value = true;
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: Text(('Mark as read').appTr,
                            style:
                            GoogleFonts.lato(fontSize: 13)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient:  LinearGradient(
                          colors: [kAppColor, kAppColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(Get.context!).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          ('Close').appTr,
                          style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      transitionDuration: const Duration(milliseconds: 280),
      transitionCurve: Curves.easeOutBack,
    );
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────
  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'user':     return Colors.blue;
      case 'host':     return Colors.green;
      case 'agency':   return Colors.orange;
      case 'reseller': return Colors.purple;
      case 'stuff':    return Colors.red;
      default:         return const Color(0xFF7F77DD);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'user':     return Icons.person;
      case 'host':     return Icons.live_tv;
      case 'agency':   return Icons.business;
      case 'reseller': return Icons.store;
      case 'stuff':    return Icons.work;
      default:         return Icons.notifications;
    }
  }

  String _formatDateTime(String dateTime) {
    try {
      final dt = DateTime.parse(dateTime);
      final diff = DateTime.now().difference(dt);
      if (diff.inDays > 0)    return '${diff.inDays}d ago';
      if (diff.inHours > 0)   return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return ('Just now').appTr;
    } catch (_) {
      return dateTime;
    }
  }
}

class _LightGlowBackground extends StatefulWidget {
  const _LightGlowBackground();

  @override
  State<_LightGlowBackground> createState() => _LightGlowBackgroundState();
}

class _LightGlowBackgroundState extends State<_LightGlowBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const Color kAppColor1 = Color(0xFFF80230);
  static const Color kAppColor2 = Color(0xFFFD375D);
  static const Color kAppbarColor = Color(0xFFF43C5D);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;

        return Container(
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
          child: Stack(
            children: [
              Positioned(
                top: -80 + (value * 25),
                right: -70,
                child: _GlowCircle(
                  size: 220,
                  color: kAppColor2.withOpacity(0.6),
                ),
              ),

              Positioned(
                top: 170 - (value * 35),
                left: -90,
                child: _GlowCircle(
                  size: 260,
                  color: kAppColor1.withOpacity(0.5),
                ),
              ),

              Positioned(
                bottom: 80 + (value * 30),
                right: -100,
                child: _GlowCircle(
                  size: 280,
                  color: kAppbarColor.withOpacity(0.4),
                ),
              ),

              Positioned(
                bottom: -90,
                left: -70 + (value * 35),
                child: _GlowCircle(
                  size: 230,
                  color: kAppColor2.withOpacity(0.2),
                ),
              ),
            ],
          ),
        );
      },
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
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 80,
              spreadRadius: 35,
            ),
          ],
        ),
      ),
    );
  }
}