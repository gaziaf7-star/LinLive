import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GradientShimmerTextaudio extends StatefulWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  /// একসাথে আনুমানিক কতগুলো letter দেখা যাবে
  final int visibleLetters;

  const GradientShimmerTextaudio({
    super.key,
    required this.text,
    required this.fontSize,
    this.fontWeight = FontWeight.w500,
    this.visibleLetters = 6,
  });

  @override
  State<GradientShimmerTextaudio> createState() =>
      _GradientShimmerTextaudioState();
}

class _GradientShimmerTextaudioState extends State<GradientShimmerTextaudio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scrollController;

  /// একটি নাম শেষ হওয়ার পর পরের নামের মাঝের ছোট gap
  static const double _gap = 8;

  @override
  void initState() {
    super.initState();

    /// আগের 15000ms থেকে কমিয়ে 7000ms করা হয়েছে।
    /// আরও দ্রুত চাইলে 6000 বা 5000 করতে পারবেন।
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant GradientShimmerTextaudio oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text) {
      _scrollController
        ..reset()
        ..repeat();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  TextStyle get _textStyle {
    return GoogleFonts.merriweather(
      fontWeight: widget.fontWeight,
      fontSize: widget.fontSize,
      height: 1.1,
      decoration: TextDecoration.none,
      decorationThickness: 0,
    );
  }

  /// Invalid বা broken UTF-16 character পরিষ্কার করবে।
  String _cleanText(String value) {
    final units = value.trim().codeUnits;
    final buffer = StringBuffer();

    for (int i = 0; i < units.length; i++) {
      final int unit = units[i];

      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (i + 1 < units.length) {
          final int next = units[i + 1];

          if (next >= 0xDC00 && next <= 0xDFFF) {
            final int codePoint =
                0x10000 + ((unit - 0xD800) << 10) + (next - 0xDC00);

            buffer.writeCharCode(codePoint);
            i++;
          }
        }

        continue;
      }

      if (unit >= 0xDC00 && unit <= 0xDFFF) {
        continue;
      }

      if (unit == 0) {
        continue;
      }

      if (unit == 10 || unit == 13 || unit == 9) {
        buffer.write(' ');
        continue;
      }

      if (unit < 32) {
        continue;
      }

      buffer.writeCharCode(unit);
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  double _getTextWidth(String text) {
    final safeText = _cleanText(text);

    if (safeText.isEmpty) {
      return 0;
    }

    try {
      final painter = TextPainter(
        text: TextSpan(
          text: safeText,
          style: _textStyle,
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      return painter.width;
    } catch (_) {
      return safeText.length * widget.fontSize * 0.65;
    }
  }

  Widget _singleText(String text) {
    final safeText = _cleanText(text);

    if (safeText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      safeText,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.visible,
      textWidthBasis: TextWidthBasis.longestLine,
      style: _textStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String showText = _cleanText(widget.text);

    if (showText.isEmpty) {
      return const SizedBox.shrink();
    }

    final double boxWidth =
        widget.fontSize * widget.visibleLetters * 0.75;

    final double boxHeight = widget.fontSize * 1.5;
    final double textWidth = _getTextWidth(showText);

    if (textWidth <= 0 || boxWidth <= 0) {
      return const SizedBox.shrink();
    }

    /// একটি text থেকে পরবর্তী text পর্যন্ত মোট দূরত্ব।
    /// এখানে boxWidth যোগ করা হয়নি, তাই বড় blank gap হবে না।
    final double cycleWidth = textWidth + _gap;

    /// ছোট নাম হলেও screen-এর ডান পাশ ফাঁকা না রাখার জন্য
    /// প্রয়োজন অনুযায়ী একই নাম কয়েকবার তৈরি করা হবে।
    final int copyCount = (boxWidth / cycleWidth).ceil() + 3;

    return SizedBox(
      width: boxWidth,
      height: boxHeight,
      child: ClipRect(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              /// 0 থেকে একটি সম্পূর্ণ cycle পর্যন্ত বাম দিকে যাবে।
              /// একটি নাম শেষ হলে পরবর্তী নাম ঠিক একই জায়গায় চলে আসবে।
              final double dx =
              -(_scrollController.value * cycleWidth);

              return ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFFFD700),
                      Color(0xFFFF6B9A),
                      Color(0xFFFFFFFF),
                      Color(0xFF00E5FF),
                      Color(0xFFFFD700),
                    ],
                    stops: [
                      0.0,
                      0.25,
                      0.50,
                      0.75,
                      1.0,
                    ],
                  ).createShader(bounds);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: List.generate(
                    copyCount,
                        (index) {
                      return Positioned(
                        left: dx + (index * cycleWidth),
                        top: 0,
                        height: boxHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _singleText(showText),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}