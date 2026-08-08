import 'package:flutter/material.dart';
import 'package:meetlivepro/constants/layout_constant.dart';


class PremiumCpCard extends StatelessWidget {
  final String myName;
  final String partnerName;
  final String myImage;
  final String partnerImage;
  final String levelText;
  final String totalDays;

  const PremiumCpCard({
    super.key,
    required this.myName,
    required this.partnerName,
    required this.myImage,
    required this.partnerImage,
    required this.levelText,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outerConstraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final width = outerConstraints.maxWidth.isFinite && outerConstraints.maxWidth > 0
            ? outerConstraints.maxWidth
            : screenWidth;

        /// Compact responsive height. Screenshot-er moto slim card.
        final cardHeight = (width * 0.29).clamp(106.0, 118.0).toDouble();
        final avatarSize = (cardHeight * 0.37).clamp(38.0, 48.0).toDouble();
        final nameFont = (cardHeight * 0.112).clamp(11.0, 13.0).toDouble();
        final daysFont = (cardHeight * 0.155).clamp(16.0, 18.0).toDouble();
        final heartWidth = (cardHeight * 0.42).clamp(40.0, 50.0).toDouble();
        final heartHeight = (cardHeight * 0.27).clamp(27.0, 32.0).toDouble();
        final heartIconSize = (heartHeight * 0.54).clamp(14.0, 18.0).toDouble();

        return SizedBox(
          width: double.infinity,
          height: cardHeight,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7D1FA4),
                  Color(0xFFB2208D),
                  Color(0xFFE23E9F),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4FA8).withOpacity(.25),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(.18),
                width: 1.2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // soft background hearts
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CustomPaint(
                      painter: _CardPatternPainter(),
                    ),
                  ),
                ),

                // top level badge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE7A642),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        levelText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),

                // decorative corners
                Positioned(
                  top: 7,
                  left: 7,
                  child: _cornerDecoration(),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: Transform.rotate(
                    angle: 1.57,
                    child: _cornerDecoration(),
                  ),
                ),
                Positioned(
                  bottom: 7,
                  left: 7,
                  child: Transform.rotate(
                    angle: -1.57,
                    child: _cornerDecoration(),
                  ),
                ),
                Positioned(
                  bottom: 7,
                  right: 7,
                  child: Transform.rotate(
                    angle: 3.14,
                    child: _cornerDecoration(),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.fromLTRB(10, 20, 10, cardHeight * 0.06),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmall = constraints.maxWidth < 360;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                // left profile
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _premiumAvatar(
                                        imageUrl: myImage,
                                        size: avatarSize,
                                        glowColor: const Color(0xFFFFC1E3),
                                      ),
                                      SizedBox(height: cardHeight * 0.02),
                                      Text(
                                        myName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: kHeight*0.012,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // center area
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(height: cardHeight * 0.01),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          _waveLine(),
                                          const SizedBox(width: 6),
                                          _heartCenterBadge(width: heartWidth, height: heartHeight, iconSize: heartIconSize),
                                          const SizedBox(width: 6),
                                          _waveLine(),
                                        ],
                                      ),
                                      SizedBox(height: cardHeight * 0.035),
                                      Text(
                                        totalDays,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: daysFont,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: cardHeight * 0.01),
                                      Container(
                                        width: (width * 0.22).clamp(72.0, 96.0).toDouble(),
                                        height: 2,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0),
                                              Colors.white.withOpacity(.9),
                                              Colors.white.withOpacity(0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // right profile
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _premiumAvatar(
                                        imageUrl: partnerImage,
                                        size: avatarSize,
                                        glowColor: const Color(0xFFFFD0EC),
                                      ),
                                      SizedBox(height: cardHeight * 0.02),
                                      Text(
                                        partnerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize:  kHeight*0.012,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // bottom decoration
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 55,
                                height: 1.3,
                                color: Colors.white.withOpacity(.45),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.favorite,
                                color: Colors.white.withOpacity(.9),
                                size: 12,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 55,
                                height: 1.3,
                                color: Colors.white.withOpacity(.45),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cornerDecoration() {
    return Icon(
      Icons.auto_awesome,
      color: Colors.white.withOpacity(.60),
      size: 10,
    );
  }

  Widget _waveLine() {
    return Expanded(
      child: Container(
        height: 1.6,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0),
              Colors.white.withOpacity(.95),
              Colors.white.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heartCenterBadge({
    required double width,
    required double height,
    required double iconSize,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFB3E1),
            Color(0xFFFF5CB8),
            Color(0xFFD4249A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7CC8).withOpacity(.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(.4),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.favorite,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }

  Widget _premiumAvatar({
    required String imageUrl,
    required double size,
    required Color glowColor,
  }) {
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF4C2),
            Color(0xFFFFD86B),
            Color(0xFFE7A642),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(.35),
            blurRadius: 8,
            spreadRadius: .6,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.4),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(.9),
              width: 1.2,
            ),
          ),
          child: ClipOval(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  color: Colors.white.withOpacity(.15),
                  child: Icon(
                    Icons.person,
                    color: Colors.white,
                    size: size * 0.52,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.05)
      ..style = PaintingStyle.fill;

    final smallCircle1 = Offset(size.width * .15, size.height * .35);
    final smallCircle2 = Offset(size.width * .82, size.height * .30);
    final smallCircle3 = Offset(size.width * .28, size.height * .72);
    final smallCircle4 = Offset(size.width * .72, size.height * .74);

    canvas.drawCircle(smallCircle1, size.height * 0.08, paint);
    canvas.drawCircle(smallCircle2, size.height * 0.07, paint);
    canvas.drawCircle(smallCircle3, size.height * 0.06, paint);
    canvas.drawCircle(smallCircle4, size.height * 0.065, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}