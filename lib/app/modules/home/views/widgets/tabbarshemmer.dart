import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

const Color kAppColor1 = Color(0xFFF80230);
const Color kAppColor2 = Color(0xFFFD375D);
const Color kAppbarColor = Color(0xFFF43C5D);

class GradientShimmerText extends StatefulWidget {
  final String text;
  final bool isSelected;
  final double fontSize;
  final FontWeight fontWeight;

  const GradientShimmerText({
    super.key,
    required this.text,
    required this.isSelected,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w800,
  });

  @override
  State<GradientShimmerText> createState() => _GradientShimmerTextState();
}

class _GradientShimmerTextState extends State<GradientShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LinearGradient _selectedGradient() {
    return const LinearGradient(
      colors: [
        kAppColor1,
        kAppColor2,
        kAppbarColor,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  LinearGradient _unSelectedGradient() {
    return LinearGradient(
      colors: [
        Colors.white.withOpacity(0.78),
        Colors.white.withOpacity(0.98),
        Colors.white.withOpacity(0.78),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final shimmerPosition = _controller.value * 3 - 1.5;

        return ShaderMask(
          shaderCallback: (bounds) {
            return widget.isSelected
                ? _selectedGradient().createShader(bounds)
                : _unSelectedGradient().createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(widget.isSelected ? 0.95 : 0.65),
                  Colors.transparent,
                ],
                stops: const [0.35, 0.50, 0.65],
                begin: Alignment(shimmerPosition - 1, 0),
                end: Alignment(shimmerPosition + 1, 0),
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          ),
        );
      },
      child: Text(
        widget.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.lato(
          fontSize: widget.fontSize,
          fontWeight: widget.fontWeight,
          letterSpacing: 0.2,
          shadows: [
            Shadow(
              color: widget.isSelected
                  ? kAppColor1.withOpacity(0.35)
                  : Colors.white.withOpacity(0.28),
              blurRadius: widget.isSelected ? 10 : 6,
              offset: const Offset(0, 0),
            ),
            Shadow(
              color: widget.isSelected
                  ? kAppColor2.withOpacity(0.35)
                  : Colors.white.withOpacity(0.18),
              blurRadius: widget.isSelected ? 16 : 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),
    );
  }
}

class GlowingTabBarBox extends StatefulWidget {
  final double kHeight;

  const GlowingTabBarBox({
    super.key,
    required this.kHeight,
  });

  @override
  State<GlowingTabBarBox> createState() => _GlowingTabBarBoxState();
}

class _GlowingTabBarBoxState extends State<GlowingTabBarBox> {
  static const Color _selectedColor1 = Color(0xff9113fa);
  static const Color _selectedColor2 = Color(0xffe208fa);

  List<String> get _tabs => [
    'Showing'.appTr,
    'Video'.appTr,
    'Audio'.appTr,
    'PK Match'.appTr,
  ];

  Widget _buildTab({
    required BuildContext context,
    required String text,
    required int index,
    required TabController controller,
  }) {
    final double screenWidth = MediaQuery.sizeOf(context).width;

    // Responsive values: small phone -> compact, large phone -> slightly bigger.
    final double tabHeight = (screenWidth * 0.082).clamp(30.0, 34.0);
    final double horizontalPadding =
    (screenWidth * 0.032).clamp(10.0, 14.0);
    final double fontSize = (screenWidth * 0.034).clamp(12.0, 14.0);
    final double iconSize = (screenWidth * 0.041).clamp(15.0, 18.0);

    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) {
        final bool isSelected = controller.index == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: tabHeight,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
              colors: [
                _selectedColor1,
                _selectedColor2,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
                : null,
            color: isSelected
                ? null
                : Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(tabHeight / 2),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.14)
                  : Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
            boxShadow: null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (index == 0) ...[
                Icon(
                  Icons.local_fire_department_rounded,
                  size: iconSize,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.72),
                ),
                SizedBox(width: (screenWidth * 0.008).clamp(3.0, 4.0)),
              ],
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.76),
                  fontSize: fontSize,
                  fontWeight:
                  isSelected ? FontWeight.w800 : FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final TabController controller = DefaultTabController.of(context);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double outerLeft = (screenWidth * 0.035).clamp(10.0, 16.0);
    final double tabGap = (screenWidth * 0.018).clamp(5.0, 8.0);
    final double rowHeight = (screenWidth * 0.105).clamp(38.0, 44.0);

    return SizedBox(
      width: double.infinity,
      height: rowHeight,
      child: TabBar(
        controller: controller,

        // Compact tabs start from the LEFT instead of filling the full width.
        isScrollable: true,
        tabAlignment: TabAlignment.start,

        indicator: const BoxDecoration(
          color: Colors.transparent,
        ),
        indicatorColor: Colors.transparent,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: MaterialStateProperty.all(Colors.transparent),
        indicatorPadding: EdgeInsets.zero,

        // First tab starts from the left with a small responsive margin.
        padding: EdgeInsets.only(
          left: outerLeft,
          right: outerLeft,
          top: 2,
          bottom: 2,
        ),

        // Responsive space between each pill/card.
        labelPadding: EdgeInsets.only(right: tabGap),

        tabs: List.generate(
          _tabs.length,
              (index) => Tab(
            height: rowHeight - 4,
            child: _buildTab(
              context: context,
              text: _tabs[index],
              index: index,
              controller: controller,
            ),
          ),
        ),
      ),
    );
  }
}
