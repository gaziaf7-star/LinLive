import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../services/cp_invite_model.dart';
import '../controllers/cpinviteController.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class CpInviteAcceptPage extends StatelessWidget {
  CpInviteAcceptPage({
    super.key,
    required this.request,
  });

  final CpInviteRequest request;

  final CpInviteController controller = Get.find<CpInviteController>();

  @override
  Widget build(BuildContext context) {
    final partner = request.partnerUser;
    final me = request.mySideUser;

    return Scaffold(
      backgroundColor: const Color(0xfffbecff),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CpInviteBgPainter(),
              ),
            ),
            Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: _inviteCard(me, partner),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xff2b2034),
            ),
          ),
           Expanded(
            child: Center(
              child: Text(
                ('CP Invitation').appTr,
                style: TextStyle(
                  color: Color(0xff2b2034),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _inviteCard(CpInviteUser me, CpInviteUser partner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xfffff4fb),
            Color(0xffffd7ec),
            Color(0xfff0d9ff),
            Color(0xfffff2f9),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(.85),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffff66b2).withOpacity(.25),
            blurRadius: 35,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CpCardDecorPainter(),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 10),

              _topGem(),

              const SizedBox(height: 18),

              _profileArea(me, partner),

              const SizedBox(height: 25),

              Text(
                ('Would you like').appTr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xffb12b8f).withOpacity(.95),
                  fontSize: 30,
                  height: 1,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                ('to be my CP?').appTr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xffb12b8f).withOpacity(.98),
                  fontSize: 44,
                  height: 1,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 15),

              Container(
                width: 210,
                height: 1.2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xffc64aa0).withOpacity(.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Text(
                request.message.isNotEmpty
                    ? request.message
                    : ('${partner.name} sent you a CP gift request.').appTr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xff8d4d80),
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              _requestInfo(partner),

              const SizedBox(height: 22),

              _actionButtons(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topGem() {
    return Column(
      children: [
        Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                Color(0xffff8bd0),
                Color(0xffb678ff),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xffff69b4).withOpacity(.45),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 34,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 18,
          width: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: const LinearGradient(
              colors: [
                Color(0xffffb1d8),
                Color(0xfffff2fb),
                Color(0xffff8cc7),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileArea(CpInviteUser me, CpInviteUser partner) {
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 22,
            child: _profileFrame(
              user: partner,
              title: ('Invited By').appTr,
              ringColor: const Color(0xffff74b5),
            ),
          ),
          Positioned(
            right: 22,
            child: _profileFrame(
              user: me,
              title: ('You').appTr,
              ringColor: const Color(0xffb279ff),
            ),
          ),
          Positioned(
            top: 55,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.55),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffff5d96).withOpacity(.60),
                    blurRadius: 25,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.favorite_rounded,
                  color: Color(0xffff4f93),
                  size: 42,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileFrame({
    required CpInviteUser user,
    required String title,
    required Color ringColor,
  }) {
    return Column(
      children: [
        Container(
          height: 104,
          width: 104,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: ringColor.withOpacity(.70),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: ringColor.withOpacity(.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: _networkImage(user.profileImage),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xff8d4d80),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          user.name.isEmpty ? ('Unknown').appTr: user.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xff2c2230),
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          ('ID: ${user.userId}').appTr,
          style: TextStyle(
            color: const Color(0xff2c2230).withOpacity(.60),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _requestInfo(CpInviteUser partner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(.90),
        ),
      ),
      child: Column(
        children: [
          _infoRow(('Request No').appTr, request.requestNo),
          const SizedBox(height: 8),
          _infoRow(('Gift').appTr, ('${request.gift?.name ?? 'CP'} • ${request.coin} coins').appTr),
          const SizedBox(height: 8),
          _infoRow(('Time').appTr, '${request.createdDate} ${request.createdTime}'),
        ],
      ),
    );
  }

  Widget _infoRow(String left, String right) {
    return Row(
      children: [
        Text(
          left,
          style: TextStyle(
            color: const Color(0xff2c2230).withOpacity(.62),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            right,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xff2c2230),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButtons() {
    if (!request.isPending) {
      return Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.65),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Center(
          child: Text(
            request.statusText,
            style: const TextStyle(
              color: Color(0xffb12b8f),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }

    return Obx(() {
      final bool loading = controller.processingRequestId.value == request.id;

      return Row(
        children: [
          Expanded(
            child: _actionButton(
              title: ('Reject').appTr,
              loading: loading,
              textColor: const Color(0xffa23a87),
              gradient: const LinearGradient(
                colors: [
                  Color(0xffffffff),
                  Color(0xffffedf7),
                ],
              ),
              onTap: request.canReject && !loading
                  ? () async {
                final ok = await controller.cpReject(id: request.id);
                if (ok) Get.back();
              }
                  : null,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: _actionButton(
              title: ('Accept').appTr,
              loading: loading,
              textColor: Colors.white,
              gradient: const LinearGradient(
                colors: [
                  Color(0xffff8ac1),
                  Color(0xffff4f9a),
                  Color(0xffe53f91),
                ],
              ),
              onTap: request.canAccept && !loading
                  ? () async {
                final ok = await controller.cpAccept(id: request.id);
                if (ok) Get.back();
              }
                  : null,
            ),
          ),
        ],
      );
    });
  }

  Widget _actionButton({
    required String title,
    required bool loading,
    required Color textColor,
    required LinearGradient gradient,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          gradient: gradient,
          border: Border.all(
            color: Colors.white.withOpacity(.90),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffff5d96).withOpacity(.18),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Center(
          child: loading
              ? SizedBox(
            width: 21,
            height: 21,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: textColor,
            ),
          )
              : Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _networkImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: const Color(0xffffd9ec),
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xffff5d96),
          size: 45,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: const Color(0xffffd9ec),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xffff5d96),
            size: 45,
          ),
        );
      },
    );
  }
}

class _CpInviteBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xfffbecff),
          Color(0xfffff6fb),
          Color(0xffffe8f4),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, bg);

    final paint = Paint();

    for (int i = 0; i < 22; i++) {
      final x = (i * 47) % size.width;
      final y = (i * 83) % size.height;

      paint.color = const Color(0xffff82bf).withOpacity(i % 2 == 0 ? .18 : .10);
      canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), 7 + (i % 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CpCardDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    paint.color = Colors.white.withOpacity(.30);
    canvas.drawCircle(Offset(size.width * .12, size.height * .08), 35, paint);
    canvas.drawCircle(Offset(size.width * .90, size.height * .15), 42, paint);
    canvas.drawCircle(Offset(size.width * .10, size.height * .86), 42, paint);
    canvas.drawCircle(Offset(size.width * .92, size.height * .88), 38, paint);

    for (int i = 0; i < 18; i++) {
      final x = (i * 31) % size.width;
      final y = (i * 59) % size.height;
      _drawHeart(
        canvas,
        Offset(x.toDouble(), y.toDouble()),
        8 + (i % 4).toDouble(),
        const Color(0xffff5d96).withOpacity(.12),
      );
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final path = Path();

    final x = center.dx;
    final y = center.dy;
    final s = size / 18;

    path.moveTo(x, y + 5 * s);
    path.cubicTo(x - 18 * s, y - 6 * s, x - 9 * s, y - 18 * s, x, y - 8 * s);
    path.cubicTo(x + 9 * s, y - 18 * s, x + 18 * s, y - 6 * s, x, y + 5 * s);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}