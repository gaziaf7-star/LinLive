import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../controllers/daily_reword_controller.dart';

Future<void> showDailyRewardDialog({
  required BuildContext context,
  DailyRewardController? controller,
  Future<bool> Function()? onSignIn,
}) {
  final DailyRewardController resolvedController = controller ??
      (Get.isRegistered<DailyRewardController>()
          ? Get.find<DailyRewardController>()
          : Get.put(DailyRewardController(), permanent: true));

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Daily Reward',
    barrierColor: Colors.black.withOpacity(0.66),
    transitionDuration: const Duration(milliseconds: 230),
    pageBuilder: (context, animation, secondaryAnimation) {
      return DailyRewardDialog(
        controller: resolvedController,
        onSignIn: onSignIn,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final Animation<double> curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.93, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class DailyRewardDialog extends StatefulWidget {
  const DailyRewardDialog({
    super.key,
    required this.controller,
    this.onSignIn,
  });

  final DailyRewardController controller;
  final Future<bool> Function()? onSignIn;

  @override
  State<DailyRewardDialog> createState() => _DailyRewardDialogState();
}

class _DailyRewardDialogState extends State<DailyRewardDialog> {
  static const Color _green = Color(0xFF62083E);
  static const Color _greenDark = Color(0xFF190522);
  static const Color _greenSoft = Color(0xFF3B072F);
  static const Color _cardColor = Color(0xFF3B072F);
  static const Color _gold = Color(0xFFFFC93D);

  final Set<String> _preCachedUrls = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await widget.controller.fetchDailyRewards(
        force: !widget.controller.hasData,
      );
      if (!mounted) return;
      _precacheStaticRewardImages();
    });
  }

  void _precacheStaticRewardImages() {
    final DailyRewardData? data = widget.controller.rewardData.value;
    if (data == null) return;

    for (final DailyRewardDay day in data.days) {
      for (final DailyRewardItem reward in day.rewards) {
        final String url = reward.mediaUrl.trim();
        if (url.isEmpty || reward.isSvga || !_isNetworkUrl(url)) continue;
        if (!_preCachedUrls.add(url)) continue;
        precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
      }
    }
  }

  Future<void> _handleRefresh() async {
    HapticFeedback.selectionClick();
    final bool success =
    await widget.controller.fetchDailyRewards(force: true);
    if (success && mounted) _precacheStaticRewardImages();
  }

  Future<void> _handleSignIn() async {
    final DailyRewardData? data = widget.controller.rewardData.value;
    if (widget.controller.isClaiming.value || data == null || !data.canClaim) {
      return;
    }

    HapticFeedback.mediumImpact();
    final bool success = widget.onSignIn != null
        ? await widget.onSignIn!.call()
        : await widget.controller.claimToday();

    if (!mounted) return;

    final String message = widget.controller.actionMessage.value.trim();
    if (message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (success) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    final double screenWidth = media.size.width;
    final double screenHeight = media.size.height;
    final double dialogWidth = math.min(screenWidth * 0.90, 365.0);
    final double dialogMaxHeight = math.min(screenHeight * 0.70, 555.0);
    final double scale = (dialogWidth / 365).clamp(0.80, 1.0).toDouble();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: math.max(10, screenWidth * 0.02),
              vertical: math.max(12, screenHeight * 0.015),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogWidth,
                maxHeight: dialogMaxHeight,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: 29 * scale),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18 * scale),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _greenDark,
                          borderRadius: BorderRadius.circular(18 * scale),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withOpacity(0.28),
                              blurRadius: 28,
                              spreadRadius: 1,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _buildHeader(scale),
                            Flexible(
                              child: Obx(() => _buildBody(scale)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -12 * scale,
                    child: _buildCalendarArt(scale),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double scale) {
    return SizedBox(
      height: 94 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFF190522),
                    Color(0xFF3B072F),
                    Color(0xFF62083E),
                  ],
                ),
              ),
              child: CustomPaint(painter: _HeaderPatternPainter()),
            ),
          ),
          Positioned(
            top: 6 * scale,
            left: 8 * scale,
            child: Obx(
                  () => _RoundHeaderButton(
                icon: widget.controller.isRefreshing.value
                    ? null
                    : Icons.refresh_rounded,
                loading: widget.controller.isRefreshing.value,
                onTap: widget.controller.isRefreshing.value
                    ? null
                    : _handleRefresh,
                size: 31 * scale,
              ),
            ),
          ),
          Positioned(
            top: 6 * scale,
            right: 8 * scale,
            child: _RoundHeaderButton(
              icon: Icons.close_rounded,
              onTap: () =>
                  Navigator.of(context, rootNavigator: true).pop(),
              size: 31 * scale,
            ),
          ),
          Positioned(
            left: 44 * scale,
            right: 44 * scale,
            bottom: 10 * scale,
            child: Obx(() {
              final DailyRewardData? data = widget.controller.rewardData.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    data?.title ?? 'Daily Reward',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 22 * scale,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    data?.subtitle ??
                        'Sign in for 7 days for rich rewards',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 10.8 * scale,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double scale) {
    final DailyRewardController controller = widget.controller;
    final DailyRewardData? data = controller.rewardData.value;

    if (controller.isLoading.value && data == null) {
      return _buildLoading(scale);
    }

    if (data == null) {
      return _buildError(scale, controller.errorMessage.value);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        8 * scale,
        10 * scale,
        8 * scale,
        9 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildRewardLayout(data, scale),
          SizedBox(height: 10 * scale),
          _buildSignInButton(data, scale),
          if (controller.errorMessage.value.isNotEmpty) ...<Widget>[
            SizedBox(height: 5 * scale),
            Text(
              controller.errorMessage.value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.red.shade600,
                fontSize: 9.5 * scale,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRewardLayout(DailyRewardData data, double scale) {
    final Map<int, DailyRewardDay> byDay = <int, DailyRewardDay>{
      for (final DailyRewardDay day in data.days) day.day: day,
    };

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap = 5.5 * scale;
        final double smallWidth = (constraints.maxWidth - (gap * 3)) / 4;
        final double mediumWidth = (constraints.maxWidth - gap) / 2;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int day = 1; day <= 4; day++) ...<Widget>[
                  SizedBox(
                    width: smallWidth,
                    child: _buildDayCard(
                      day: byDay[day] ?? _emptyDay(day),
                      currentDay: data.currentDay,
                      widthMode: _RewardCardWidth.small,
                      scale: scale,
                    ),
                  ),
                  if (day != 4) SizedBox(width: gap),
                ],
              ],
            ),
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: mediumWidth,
                  child: _buildDayCard(
                    day: byDay[5] ?? _emptyDay(5),
                    currentDay: data.currentDay,
                    widthMode: _RewardCardWidth.medium,
                    scale: scale,
                  ),
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: mediumWidth,
                  child: _buildDayCard(
                    day: byDay[6] ?? _emptyDay(6),
                    currentDay: data.currentDay,
                    widthMode: _RewardCardWidth.medium,
                    scale: scale,
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            _buildDayCard(
              day: byDay[7] ?? _emptyDay(7, big: true),
              currentDay: data.currentDay,
              widthMode: _RewardCardWidth.large,
              scale: scale,
            ),
          ],
        );
      },
    );
  }

  DailyRewardDay _emptyDay(int day, {bool big = false}) {
    return DailyRewardDay(
      day: day,
      title: 'Day $day',
      isBigReward: big,
      maxActive: 0,
      rewards: const <DailyRewardItem>[],
    );
  }

  Widget _buildDayCard({
    required DailyRewardDay day,
    required int currentDay,
    required _RewardCardWidth widthMode,
    required double scale,
  }) {
    final bool active = currentDay == day.day;
    final bool completed = day.day < currentDay;
    final bool big = day.isBigReward || widthMode == _RewardCardWidth.large;
    final double height = switch (widthMode) {
      _RewardCardWidth.small => 104 * scale,
      _RewardCardWidth.medium => 118 * scale,
      _RewardCardWidth.large => 126 * scale,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: active
              ? const <Color>[
            Color(0xFF62083E),
            Color(0xFF3B072F),
            Color(0xFF190522),
          ]
              : const <Color>[
            Color(0xFF190522),
            Color(0xFF3B072F),
            Color(0xFF62083E),
          ],
        ),
        borderRadius: BorderRadius.circular(9 * scale),
        border: Border.all(
          color: active
              ? _gold
              : big
              ? _gold.withOpacity(0.75)
              : Colors.white.withOpacity(0.16),
          width: active ? 1.7 : 1,
        ),
        boxShadow: active
            ? <BoxShadow>[
          BoxShadow(
            color: _green.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ]
            : const <BoxShadow>[],
      ),
      child: Stack(
        children: <Widget>[
          if (big)
            Positioned(
              right: -22 * scale,
              bottom: -24 * scale,
              child: Icon(
                Icons.card_giftcard_rounded,
                size: 92 * scale,
                color: _gold.withOpacity(0.16),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                4 * scale,
                27 * scale,
                4 * scale,
                5 * scale,
              ),
              child: day.rewards.isEmpty
                  ? Center(
                child: Icon(
                  Icons.card_giftcard_rounded,
                  size: 28 * scale,
                  color: Colors.grey.shade400,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: day.rewards
                    .map(
                      (DailyRewardItem reward) => Expanded(
                    child: _RewardItemView(
                      reward: reward,
                      scale: scale,
                      compact:
                      widthMode == _RewardCardWidth.small,
                    ),
                  ),
                )
                    .toList(growable: false),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              height: 27 * scale,
              padding: EdgeInsets.symmetric(horizontal: 9 * scale),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: completed
                      ? const <Color>[Color(0xFF3B072F), Color(0xFF62083E)]
                      : active
                      ? const <Color>[Color(0xFF62083E), Color(0xFF3B072F)]
                      : const <Color>[Color(0xFF190522), Color(0xFF62083E)],
                ),
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(8 * scale),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (completed) ...<Widget>[
                    Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 12 * scale,
                    ),
                    SizedBox(width: 2 * scale),
                  ],
                  Text(
                    '${day.day}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12.5 * scale,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (big)
            Positioned(
              left: 37 * scale,
              top: 0,
              child: Container(
                height: 24 * scale,
                padding: EdgeInsets.symmetric(horizontal: 10 * scale),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFFFA31B), Color(0xFFFFC23D)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(6 * scale),
                  ),
                ),
                child: Text(
                  'Big Reward',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 9.6 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignInButton(DailyRewardData data, double scale) {
    return Obx(() {
      final bool loading = widget.controller.isClaiming.value;
      final bool enabled = data.canClaim && !loading;
      final String label = data.claimedToday
          ? 'Claimed Today'
          : data.buttonText.trim().isEmpty
          ? 'Sign In'
          : data.buttonText;

      return SizedBox(
        width: double.infinity,
        height: 40 * scale,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
              colors: <Color>[
                Color(0xFF190522),
                Color(0xFF3B072F),
                Color(0xFF62083E),
              ],
            )
                : const LinearGradient(
              colors: <Color>[Color(0xFF3B072F), Color(0xFF62083E)],
            ),
            borderRadius: BorderRadius.circular(24 * scale),
            boxShadow: enabled
                ? <BoxShadow>[
              BoxShadow(
                color: _green.withOpacity(0.23),
                blurRadius: 11,
                offset: const Offset(0, 5),
              ),
            ]
                : const <BoxShadow>[],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? _handleSignIn : null,
              borderRadius: BorderRadius.circular(24 * scale),
              child: Center(
                child: loading
                    ? SizedBox(
                  width: 19 * scale,
                  height: 19 * scale,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2.3,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      data.claimedToday
                          ? Icons.check_circle_rounded
                          : Icons.touch_app_rounded,
                      color: Colors.white,
                      size: 17 * scale,
                    ),
                    SizedBox(width: 6 * scale),
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15.5 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildLoading(double scale) {
    return Padding(
      padding: EdgeInsets.all(10 * scale),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: List<Widget>.generate(
              4,
                  (int index) => Expanded(
                child: Container(
                  height: 94 * scale,
                  margin: EdgeInsets.only(
                    right: index == 3 ? 0 : 5 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B072F),
                    borderRadius: BorderRadius.circular(9 * scale),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 6 * scale),
          Container(
            height: 101 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFF3B072F),
              borderRadius: BorderRadius.circular(9 * scale),
            ),
          ),
          SizedBox(height: 6 * scale),
          Container(
            height: 105 * scale,
            decoration: BoxDecoration(
              color: const Color(0xFF62083E),
              borderRadius: BorderRadius.circular(9 * scale),
            ),
          ),
          SizedBox(height: 10 * scale),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(double scale, String message) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18 * scale,
        28 * scale,
        18 * scale,
        24 * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56 * scale,
            height: 56 * scale,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[
                  Color(0xFF190522),
                  Color(0xFF3B072F),
                  Color(0xFF62083E),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              color: _greenDark,
              size: 29 * scale,
            ),
          ),
          SizedBox(height: 10 * scale),
          Text(
            message.trim().isEmpty
                ? 'Could not load daily rewards'
                : message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 12.5 * scale,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12 * scale),
          OutlinedButton.icon(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _greenDark,
              side: const BorderSide(color: _green),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22 * scale),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarArt(double scale) {
    return SizedBox(
      width: 142 * scale,
      height: 73 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: 8 * scale,
            child: Container(
              width: 91 * scale,
              height: 59 * scale,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11 * scale),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withOpacity(0.17),
                    blurRadius: 9 * scale,
                    offset: Offset(0, 5 * scale),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 18 * scale,
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(11 * scale),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 22 * scale,
                    child: Icon(
                      Icons.check_rounded,
                      color: _green,
                      size: 34 * scale,
                    ),
                  ),
                  Positioned(
                    top: -8 * scale,
                    left: 18 * scale,
                    child: _calendarRing(scale),
                  ),
                  Positioned(
                    top: -8 * scale,
                    right: 18 * scale,
                    child: _calendarRing(scale),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 22 * scale,
            child: Icon(
              Icons.star_rounded,
              color: Colors.amber,
              size: 23 * scale,
            ),
          ),
          Positioned(
            right: 0,
            top: 34 * scale,
            child: Icon(
              Icons.star_rounded,
              color: Colors.amber,
              size: 26 * scale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendarRing(double scale) {
    return Container(
      width: 10 * scale,
      height: 23 * scale,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7 * scale),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

class _RewardItemView extends StatelessWidget {
  const _RewardItemView({
    required this.reward,
    required this.scale,
    required this.compact,
  });

  final DailyRewardItem reward;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double mediaSize = (compact ? 42 : 50) * scale;
    final String title = reward.title.trim().isEmpty ? 'Reward' : reward.title;
    final String label = reward.bottomLabel;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 1.5 * scale),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: RepaintBoundary(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      height: mediaSize,
                      width: mediaSize,
                      child: _RewardMedia(
                        reward: reward,
                        size: mediaSize,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 2 * scale),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: (compact ? 7.2 : 8.7) * scale,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2 * scale),
              Container(
                constraints: BoxConstraints(maxWidth: 68 * scale),
                padding: EdgeInsets.symmetric(
                  horizontal: 5 * scale,
                  vertical: 1.7 * scale,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12 * scale),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: (compact ? 7.0 : 8.0) * scale,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RewardMedia extends StatelessWidget {
  const _RewardMedia({required this.reward, required this.size});

  final DailyRewardItem reward;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String media = reward.mediaUrl.trim();
    if (media.isEmpty) return _fallback();

    if (reward.isSvga) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.15),
        child: IgnorePointer(
          child: _isNetworkUrl(media)
              ? SVGAEasyPlayer(resUrl: media, fit: BoxFit.contain)
              : SVGAEasyPlayer(assetsName: media, fit: BoxFit.contain),
        ),
      );
    }

    if (_isNetworkUrl(media)) {
      return CachedNetworkImage(
        imageUrl: media,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 100),
        fadeOutDuration: Duration.zero,
        memCacheWidth: (size * 3).round(),
        placeholder: (BuildContext context, String url) => Center(
          child: SizedBox(
            width: size * 0.28,
            height: size * 0.28,
            child: const CircularProgressIndicator(
              strokeWidth: 1.8,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF62083E)),
            ),
          ),
        ),
        errorWidget: (BuildContext context, String url, Object error) =>
            _fallback(),
      );
    }

    return Image.asset(
      media,
      fit: BoxFit.contain,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          _fallback(),
    );
  }

  Widget _fallback() {
    IconData icon = Icons.card_giftcard_rounded;
    final String type = reward.rewardType.toLowerCase();
    if (type == 'coin') icon = Icons.monetization_on_rounded;
    if (type == 'vehicle') icon = Icons.directions_car_filled_rounded;
    if (type == 'frame') icon = Icons.workspace_premium_rounded;

    return Center(
      child: Icon(
        icon,
        color: type == 'coin'
            ? const Color(0xFFFFB51E)
            : const Color(0xFF62083E),
        size: size * 0.72,
      ),
    );
  }
}

class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({
    required this.size,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  final double size;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: loading
                ? SizedBox(
              width: size * 0.44,
              height: size * 0.44,
              child: const CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : Icon(
              icon,
              color: Colors.white,
              size: size * 0.68,
            ),
          ),
        ),
      ),
    );
  }
}

enum _RewardCardWidth { small, medium, large }

class _HeaderPatternPainter extends CustomPainter {
  const _HeaderPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = Colors.white.withOpacity(0.08);

    final List<Path> paths = <Path>[
      Path()
        ..moveTo(-14, size.height + 8)
        ..lineTo(22, size.height - 22)
        ..lineTo(50, size.height + 1)
        ..lineTo(84, size.height - 34),
      Path()
        ..moveTo(size.width - 90, 18)
        ..lineTo(size.width - 58, 45)
        ..lineTo(size.width - 27, 18)
        ..lineTo(size.width + 8, 48),
    ];

    for (final Path path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

bool _isNetworkUrl(String value) {
  final String lower = value.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}
