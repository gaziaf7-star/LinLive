import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';

import '../../../../constants/constants.dart';
import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../../appmenu/views/widgets/host_agency_under_data.dart';
import '../../home/controllers/home_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class LightSweepContainer2 extends StatefulWidget {
  const LightSweepContainer2({super.key});

  @override
  State<LightSweepContainer2> createState() => _LightSweepContainer2State();
}

class _LightSweepContainer2State extends State<LightSweepContainer2> {
  final HomeController homeController = Get.find<HomeController>();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (homeController.agencyUnderHost.isEmpty &&
          !homeController.agencyUnderHostLoading.value) {
        homeController.agencyUnderHostList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = authController.userProfile.value.user;
      final String hostType =
          user?.hostType?.toString().trim().toLowerCase() ?? '';

      if (hostType != 'host') {
        return const SizedBox.shrink();
      }

      final Map<String, dynamic> agency = homeController.hasAcceptedAgency
          ? homeController.acceptedAgencyData
          : <String, dynamic>{};

      final String agencyName = _validText(agency['name'])
          ? agency['name'].toString()
          : _validText(user?.name)
          ? user!.name.toString()
          : 'Host Account';

      final String userId = _validText(agency['user_id'])
          ? agency['user_id'].toString()
          : user?.userId?.toString() ?? 'N/A';

      final String agencyId = _validText(agency['agency_id'])
          ? agency['agency_id'].toString()
          : user?.agencyId?.toString() ?? 'N/A';

      final String profileImage = _validText(agency['profile_image'])
          ? agency['profile_image'].toString()
          : user?.profileImage?.toString() ?? '';

      return _buildCard(
        agency: agency,
        agencyName: agencyName,
        userId: userId,
        agencyId: agencyId,
        profileImage: profileImage,
        accepted: homeController.hasAcceptedAgency,
        loading: homeController.agencyUnderHostLoading.value,
      );
    });
  }

  bool _validText(dynamic value) {
    if (value == null) return false;
    final String text = value.toString().trim();
    return text.isNotEmpty && text.toLowerCase() != 'null' && text != '0';
  }

  Widget _buildCard({
    required Map<String, dynamic> agency,
    required String agencyName,
    required String userId,
    required String agencyId,
    required String profileImage,
    required bool accepted,
    required bool loading,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        /// Simple family-card style responsive height.
        /// Normal mobile: around 95-100px, small phone: 86px, big phone: max 105px.
        final double cardHeight = (width * 0.25).clamp(86.0, 105.0).toDouble();
        final double radius = 6;
        final double avatarBox = (cardHeight * 0.82).clamp(70.0, 86.0).toDouble();

        return Container(
          width: double.infinity,
          height: cardHeight,
          margin: EdgeInsets.symmetric(
            horizontal: kWeight * 0.02,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: () {
                if (accepted && agency.isNotEmpty) {
                  Get.to(
                        () => host_under_agency(
                      verificationData: agency,
                    ),
                  );
                } else {
                  homeController.agencyUnderHostList();
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xFF36310E),
                            Color(0xFF6B5815),
                            Color(0xFF8A7427),
                            Color(0xFF5C4B14),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SimpleAgencyCardPainter(),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radius),
                        border: Border.all(
                          color: const Color(0xFFFFDE70).withOpacity(0.32),
                          width: 1,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: (width * 0.032).clamp(10.0, 14.0),
                        vertical: (cardHeight * 0.08).clamp(6.0, 9.0),
                      ),
                      child: Row(
                        children: [
                          _buildProfileImage(
                            profileImage: profileImage,
                            size: avatarBox,
                          ),
                          SizedBox(width: (width * 0.03).clamp(9.0, 13.0)),
                          Expanded(
                            child: _buildInformation(
                              agencyName: agencyName,
                              userId: userId,
                              agencyId: agencyId,
                              accepted: accepted,
                              loading: loading,
                              cardHeight: cardHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileImage({
    required String profileImage,
    required double size,
  }) {
    final double imageSize = size * 0.62;

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFD45B),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD45B).withOpacity(0.22),
                  blurRadius: 9,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: ImageHelper.getImageUrl(
                  profileImage.isNotEmpty ? profileImage : 'default.png',
                ),
                fit: BoxFit.cover,
                placeholder: (context, url) {
                  return Container(
                    color: const Color(0xFF3A3310),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFFD45B),
                      ),
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  return const Icon(
                    Icons.person_rounded,
                    color: Colors.white70,
                    size: 28,
                  );
                },
              ),
            ),
          ),

          /// Keep the existing agency frame, but card is now simple.
          SizedBox(
            height: size,
            width: size,
            child: const SVGAEasyPlayer(
              assetsName: 'assets/svga/Frame/Agency frame.svga',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInformation({
    required String agencyName,
    required String userId,
    required String agencyId,
    required bool accepted,
    required bool loading,
    required double cardHeight,
  }) {
    final double titleFont = (cardHeight * 0.13).clamp(12.0, 14.5).toDouble();
    final double smallFont = (cardHeight * 0.105).clamp(10.0, 12.0).toDouble();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: _nameRibbon(
                title: agencyName,
                fontSize: titleFont,
              ),
            ),
            const SizedBox(width: 6),
            _memberChip(
              accepted: accepted,
              loading: loading,
              fontSize: smallFont,
            ),
          ],
        ),
        SizedBox(height: (cardHeight * 0.07).clamp(5.0, 8.0)),
        _rankPill(cardHeight: cardHeight),
        SizedBox(height: (cardHeight * 0.07).clamp(5.0, 8.0)),
        Text(
          ('Agency ID:$agencyId  |  UID:$userId').appTr,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.78),
            fontSize: smallFont,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _nameRibbon({
    required String title,
    required double fontSize,
  }) {
    return Container(
      height: 24,
      padding: const EdgeInsets.only(left: 6, right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF7A0D12).withOpacity(0.88),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFFFFC94B),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 18,
            width: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD35C),
                  Color(0xFFC56E00),
                ],
              ),
            ),
            child: const Icon(
              Icons.card_membership_rounded,
              size: 12,
              color: Color(0xFF74210B),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFFFFF1B4),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberChip({
    required bool accepted,
    required bool loading,
    required double fontSize,
  }) {
    final String text = loading
        ? 'Loading'
        : accepted
        ? 'Member': ('Host').appTr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF236577).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _rankPill({
    required double cardHeight,
  }) {
    return Container(
      height: (cardHeight * 0.22).clamp(20.0, 24.0),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD45B).withOpacity(0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFD45B),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            ('No.99+').appTr,
            style: TextStyle(
              color: Colors.white.withOpacity(0.90),
              fontSize: (cardHeight * 0.105).clamp(10.0, 12.0),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleAgencyCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    final Paint leftShade = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withOpacity(0.32),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, leftShade);

    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.95, -0.9),
        radius: 1.2,
        colors: [
          const Color(0xFFFFE189).withOpacity(0.16),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint);

    final Paint stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..strokeWidth = 1.2;

    for (double x = size.width * 0.35; x < size.width * 1.2; x += 36) {
      canvas.drawLine(
        Offset(x, -10),
        Offset(x - 55, size.height + 12),
        stripePaint,
      );
    }

    final Paint circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFD45B).withOpacity(0.12);

    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.16),
      size.height * 0.55,
      circlePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.08, size.height * 0.86),
      size.height * 0.35,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
