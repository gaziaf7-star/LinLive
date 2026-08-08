import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';
import 'package:meetlivepro/constants/layout_constant.dart';

class RechargeCoinPopup extends StatefulWidget {
  final int addedCoins;
  final int newCoins;
  final String source;
  final Future<void> Function() onClaim;

  const RechargeCoinPopup({
    super.key,
    required this.addedCoins,
    required this.newCoins,
    required this.source,
    required this.onClaim,
  });

  @override
  State<RechargeCoinPopup> createState() => _RechargeCoinPopupState();
}

class _RechargeCoinPopupState extends State<RechargeCoinPopup> {
  bool _isClaiming = false;
  bool _isClaimed = false;

  Future<void> _claim() async {
    if (_isClaiming || _isClaimed) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isClaiming = true;
    });

    try {
      await widget.onClaim();

      if (!mounted) return;

      setState(() {
        _isClaiming = false;
        _isClaimed = true;
      });

      HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 350));

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isClaiming = false;
      });

    }
  }

  String _formatNumber(int value) {
    final String text = value.abs().toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final int left = text.length - i;
      buffer.write(text[i]);
      if (left > 1 && left % 3 == 1) {
        buffer.write(',');
      }
    }

    return value < 0 ? '-$buffer' : buffer.toString();
  }

  String _sourceTitle() {
    switch (widget.source.trim().toLowerCase()) {
      case 'reseller_recharge':
        return ('Reseller Recharge').appTr;
      case 'admin_recharge':
      case 'admin_direct_recharge':
        return ('Admin Recharge').appTr;
      case 'coin_store_topup':
      case 'coin_store_recharge':
        return ('Coin Recharge').appTr;
      case 'recharge_offer':
        return ('Recharge Offer').appTr;
      default:
        return ('Recharge Successful').appTr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double width = (screen.width * .87).clamp(286.0, 390.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        child: Center(
          child: SizedBox(
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                _buildCard(width),
                Positioned(
                  top: -45,
                  child: _buildTopCoinImage(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(double width) {
    return Container(
      margin: const EdgeInsets.only(top: 70, bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff9f164a),
            Color(0xff681033),
            Color(0xff350817),
          ],
          stops: [0, .52, 1],
        ),
        border: Border.all(
          color: const Color(0xffffdf8d).withOpacity(.70),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff22030f).withOpacity(.55),
            blurRadius: 34,
            spreadRadius: 1,
            offset: const Offset(0, 19),
          ),
          BoxShadow(
            color: const Color(0xffffc85b).withOpacity(.18),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(29),
        child: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _Recharge3DBackgroundPainter(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 42, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.10),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(.16),
                        width: .8,
                      ),
                    ),
                    child: Text(
                      _sourceTitle(),
                      style: GoogleFonts.poppins(
                        color: const Color(0xffffe8b0),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    ('Your Recharge Coin').appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ('Tap Claim to add these coins to your balance').appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(.68),
                      fontSize: 10.5,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildCoinAmountPanel(),
                  const SizedBox(height: 13),
                  Text(
                    '${('Balance after claim').appTr}: ${_formatNumber(widget.newCoins)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: const Color(0xffffe5a5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildClaimButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCoinImage() {
    return SizedBox(
      width: kWeight*0.81,
      height: 164,
      child: Image.asset(
        'assets/audio_live/coinreword-removebg-preview.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.monetization_on_rounded,
          color: Color(0xffffd35d),
          size: 110,
        ),
      ),
    );
  }

  Widget _buildCoinAmountPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(.15),
            Colors.white.withOpacity(.075),
          ],
        ),
        border: Border.all(
          color: const Color(0xffffda82).withOpacity(.45),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(.07),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/frame/diamonds.png',
            width: 29,
            height: 29,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.monetization_on_rounded,
              color: Color(0xffffd35d),
              size: 29,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xfffff1a9),
                  Color(0xffffc22c),
                  Color(0xffffed9d),
                ],
              ).createShader(bounds),
              child: Text(
                '+${_formatNumber(widget.addedCoins)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(.35),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            ('Coins').appTr,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(.90),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimButton() {
    final String label = _isClaimed
        ? ('Claimed').appTr
        : _isClaiming
        ? ('Claiming...').appTr
        : ('Claim').appTr;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: _isClaimed ? 2 : 6),
      decoration: BoxDecoration(
        color: _isClaimed
            ? const Color(0xff176f49)
            : const Color(0xff9b5500),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffffc534).withOpacity(.27),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isClaiming || _isClaimed ? null : _claim,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 53,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isClaimed
                    ? const [Color(0xff35c987), Color(0xff1a8b59)]
                    : const [Color(0xffffe16e), Color(0xffffad12)],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(.62),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isClaimed
                      ? Icons.check_circle_rounded
                      : _isClaiming
                      ? Icons.hourglass_top_rounded
                      : Icons.card_giftcard_rounded,
                  color: _isClaimed
                      ? Colors.white
                      : const Color(0xff6e3300),
                  size: 21,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: _isClaimed
                        ? Colors.white
                        : const Color(0xff552700),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Recharge3DBackgroundPainter extends CustomPainter {
  const _Recharge3DBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xffffd477).withOpacity(.24),
          const Color(0xffffd477).withOpacity(0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .82, size.height * .18),
          radius: size.width * .55,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * .82, size.height * .18),
      size.width * .55,
      glowPaint,
    );

    final Paint linePaint = Paint()
      ..color = Colors.white.withOpacity(.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;

    const double gap = 34;
    for (double y = 16; y < size.height; y += gap) {
      for (double x = 16; x < size.width; x += gap) {
        final Path path = Path()
          ..moveTo(x, y - 4)
          ..lineTo(x + 4, y)
          ..lineTo(x, y + 4)
          ..lineTo(x - 4, y)
          ..close();
        canvas.drawPath(path, linePaint);
      }
    }

    final Paint bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(.17),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
