import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import '../../../../constants/image_helper.dart';
import '../../../../constants/layout_constant.dart';
import '../controllers/roket_controller.dart';
import 'audioRoomSupport.dart';

const String _rocketPlatformAsset =
    'assets/audio_live/roketbody.png';


String _rocketImage(Map<String, dynamic> item) {
  final dynamic raw = item['rocket_image'] ??
      item['rocket_image_url'] ??
      item['image'] ??
      item['show_image'] ??
      item['icon'];
  final String path = raw?.toString().trim() ?? '';
  if (path.isEmpty || path.toLowerCase() == 'null') return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return ImageHelper.getImageUrl(path);
}


class AudioRocketGameEntryButton extends StatefulWidget {
  const AudioRocketGameEntryButton({
    super.key,
    required this.livestreamId,
    this.height,
    this.width,
  });

  final int livestreamId;
  final double? height;
  final double? width;

  @override
  State<AudioRocketGameEntryButton> createState() =>
      _AudioRocketGameEntryButtonState();
}

class _AudioRocketGameEntryButtonState
    extends State<AudioRocketGameEntryButton> {
  late final RocketController controller;
  double? _lastLoggedProgress;

  @override
  void initState() {
    super.initState();
    controller = Get.isRegistered<RocketController>()
        ? Get.find<RocketController>()
        : Get.put(RocketController(), permanent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.livestreamId > 0) {
        controller.bindLivestream(widget.livestreamId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AudioRocketGameEntryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.livestreamId > 0 &&
        widget.livestreamId != oldWidget.livestreamId) {
      controller.bindLivestream(widget.livestreamId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double h = widget.height ?? kHeight * .08;
    final double w = widget.width ?? kHeight * .07;

    return Obx(() {
      if (!controller.enabled.value && !controller.loading.value) {
        return const SizedBox.shrink();
      }

      final String imageUrl = _rocketImage(
        controller.currentLevel.isNotEmpty
            ? controller.currentLevel
            : controller.levels.isNotEmpty
            ? controller.levels.first
            : const <String, dynamic>{},
      );

      final double safeProgress =
      (controller.progressPercent.value / 100).clamp(0.0, 1.0).toDouble();
      if (_lastLoggedProgress != controller.progressPercent.value) {
        _lastLoggedProgress = controller.progressPercent.value;
        debugPrint(
          '[ROCKET_UI][PROGRESS] '
          'percent=${controller.progressPercent.value.toStringAsFixed(2)}',
        );
      }

      return Padding(
        padding: EdgeInsets.only(top: kHeight * .010),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => RocketGameEventSheet.show(
            livestreamId: widget.livestreamId,
          ),
          child: SizedBox(
            width: w + 8,
            height: h + 14,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: imageUrl.isEmpty
                      ? const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 38,
                  )
                      : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    fadeInDuration: Duration.zero,
                    memCacheWidth: 180,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 32,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: safeProgress,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xff55f4ff),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  controller.progressPercent.value >= 100
                      ? 'READY'
                      : '${controller.progressPercent.value.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    shadows: <Shadow>[
                      Shadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class RocketGameEventSheet extends StatefulWidget {
  const RocketGameEventSheet({
    super.key,
    required this.livestreamId,
  });

  final int livestreamId;

  static Future<void> show({required int livestreamId}) async {
    if (livestreamId <= 0) {
      Fluttertoast.showToast(msg: 'Live room not found');
      return;
    }

    final RocketController controller = Get.isRegistered<RocketController>()
        ? Get.find<RocketController>()
        : Get.put(RocketController(), permanent: true);

    // Start loading without waiting, then open immediately.
    unawaited(controller.bindLivestream(livestreamId, force: false));

    Get.bottomSheet(
      RocketGameEventSheet(livestreamId: livestreamId),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      ignoreSafeArea: false,
      isDismissible: true,
      enableDrag: true,
    );

    /// Only ranking is needed for the visible Rocket sheet.
    /// History and My Rewards were removed from the bottom area, so those
    /// requests no longer delay or waste work while opening the sheet.
    unawaited(
      controller.fetchRanking(livestreamId: livestreamId),
    );
  }

  @override
  State<RocketGameEventSheet> createState() => _RocketGameEventSheetState();
}

class _RocketGameEventSheetState extends State<RocketGameEventSheet> {
  late final RocketController controller;

  Map<String, dynamic> _selectedLevel = <String, dynamic>{};
  int _rewardTabIndex = 0;

  @override
  void initState() {
    super.initState();
    controller = Get.find<RocketController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _selectCurrentLevel());
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! Iterable) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((Map raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _text(dynamic value, [String fallback = '']) {
    final String text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  String _image(dynamic value) {
    final String path = _text(value);
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return ImageHelper.getImageUrl(path);
  }

  String _levelImage(Map<String, dynamic> item) {
    return _image(
      item['rocket_image'] ??
          item['rocket_image_url'] ??
          item['image'] ??
          item['image_url'] ??
          item['show_image'] ??
          item['icon'],
    );
  }

  int _levelId(Map<String, dynamic> item) {
    return _int(item['id'] ?? item['level_id'] ?? item['rocket_level_id']);
  }

  int _levelNo(Map<String, dynamic> item) {
    return _int(item['level_no'] ?? item['level'] ?? item['sort_order']);
  }

  String _levelKey(Map<String, dynamic> item) {
    return '${_levelId(item)}|${_levelNo(item)}';
  }

  List<Map<String, dynamic>> _orderedLevels() {
    final List<Map<String, dynamic>> rows =
    controller.levels.map((e) => Map<String, dynamic>.from(e)).toList();
    rows.sort((a, b) => _levelNo(b).compareTo(_levelNo(a)));
    return rows;
  }

  void _selectCurrentLevel() {
    if (!mounted) return;
    final List<Map<String, dynamic>> rows = _orderedLevels();
    if (rows.isEmpty) {
      if (controller.currentLevel.isNotEmpty) {
        setState(() {
          _selectedLevel = Map<String, dynamic>.from(controller.currentLevel);
        });
      }
      return;
    }

    final int currentNo = controller.levelNo.value;
    Map<String, dynamic> selected = rows.first;
    for (final Map<String, dynamic> row in rows) {
      if (_levelNo(row) == currentNo) {
        selected = row;
        break;
      }
    }

    setState(() {
      _selectedLevel = Map<String, dynamic>.from(selected);
    });

    // Warm the small level images after the first frame so level taps switch
    // instantly without adding work to the sheet opening animation.
    for (final Map<String, dynamic> row in rows.take(10)) {
      final String url = _levelImage(row);
      if (url.isEmpty) continue;
      unawaited(
        precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {}),
      );
    }
  }

  String _compact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return '$value';
  }

  double _selectedProgress(Map<String, dynamic> selected) {
    final int selectedNo = _levelNo(selected);
    final int currentNo = controller.levelNo.value;
    if (selectedNo <= 0) return controller.progressPercent.value;
    if (selectedNo < currentNo) return 100;
    if (selectedNo > currentNo) return 0;
    return controller.progressPercent.value.clamp(0, 100).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;

    // Shorter bottom sheet while keeping the content scrollable.
    final double sheetHeight = (screen.height * .70).clamp(540.0, 760.0);

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              height: sheetHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: const _RocketSheetBackdropPainter(),
                      child: Column(
                        children: <Widget>[
                          _compactHeader(),
                          Expanded(
                            child: Obx(() {
                              if (controller.loading.value && controller.rocket.isEmpty) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (!controller.enabled.value) {
                                return const Center(
                                  child: Text(
                                    'Rocket system is currently disabled',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }

                              final List<Map<String, dynamic>> levels = _orderedLevels();
                              if (_selectedLevel.isEmpty) {
                                _selectedLevel = levels.isNotEmpty
                                    ? Map<String, dynamic>.from(levels.first)
                                    : controller.currentLevel.isNotEmpty
                                    ? Map<String, dynamic>.from(controller.currentLevel)
                                    : <String, dynamic>{};
                              }

                              final bool selectedStillExists = levels.any(
                                    (row) => _levelKey(row) == _levelKey(_selectedLevel),
                              );
                              if (!selectedStillExists && levels.isNotEmpty) {
                                _selectedLevel = Map<String, dynamic>.from(levels.first);
                              }

                              return LayoutBuilder(
                                builder: (BuildContext context, BoxConstraints box) {
                                  return SingleChildScrollView(

                                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                                    child: Column(
                                      children: <Widget>[
                                        _rocketStage(levels, box.maxWidth),
                                        const SizedBox(height: 6),
                                        _rewardPanel(box.maxWidth),
                                        const SizedBox(height: 7),
                                        _rankingPanel(),
                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tapping this transparent top strip closes the bottom sheet.
                  Positioned(
                    left: 0.0,
                    right: 0.0,
                    top: 0.0,
                    height: 46.0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => Get.back(),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactHeader() {
    // The supplied reference has no solid app-bar/header over the room.
    return const SizedBox(height: 0);
  }

  Widget _rocketStage(List<Map<String, dynamic>> levels, double width) {
    final bool compact = width < 370;
    final double stageHeight = compact ? 330 : 372;

    // Slightly wider rail so the API rockets can be visibly larger.
    final double railWidth = compact ? 66 : 74;
    final double progressWidth = compact ? 50 : 58;

    // Platform remains large, but is constrained inside the center area so it
    // never covers the left rocket list.
    final double platformWidth = compact ? 306 : 356;
    final double platformHeight = compact ? 178 : 210;
    final double rocketHeight = compact ? 300 : 348;

    final String selectedImage = _levelImage(_selectedLevel);
    final int selectedNo = _levelNo(_selectedLevel);
    final double progress = _selectedProgress(_selectedLevel);

    return SizedBox(
      height: stageHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Question badge, placed on the left like the reference.
          Positioned(
            left: 12,
            top: compact ? 56 : 68,
            child: Container(
              width: compact ? 30 : 34,
              height: compact ? 30 : 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[Color(0xff2bd8d8), Color(0xff087c87)],
                ),
                border: Border.all(
                  color: const Color(0xff9fffff),
                  width: 1.4,
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x6626f4ef), blurRadius: 8),
                ],
              ),
              child: const Icon(
                Icons.question_mark_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),

          Positioned(
            left: 0,
            top: compact ? 94 : 108,
            child: _recordButton(),
          ),

          // Main API rocket and the uploaded platform. The platform deliberately
          // overflows the center column so it appears wide like the screenshot.
          Positioned(
            left: railWidth + 4,
            right: progressWidth + 4,
            top: 0,
            bottom: 34,
            child: LayoutBuilder(
              builder: (_, BoxConstraints box) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned(
                      // Larger platform sits lower while the left-side
                      // selector remains painted above it.
                      bottom: compact ? -48.0 : -56.0,
                      child: SizedBox(
                        width: math.min(
                          platformWidth,
                          box.maxWidth + (compact ? 36 : 42),
                        ),
                        height: platformHeight,
                        child: Image.asset(
                          _rocketPlatformAsset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => const CustomPaint(
                            painter: _RocketPlatformFallbackPainter(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: compact ? 6 : 12,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        reverseDuration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.linear,
                        switchOutCurve: Curves.linear,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          final Animation<double> fade = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                            reverseCurve: Curves.easeInCubic,
                          );
                          final Animation<double> scale =
                          Tween<double>(begin: .88, end: 1).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                              reverseCurve: Curves.easeInCubic,
                            ),
                          );
                          return FadeTransition(
                            opacity: fade,
                            child: ScaleTransition(
                              scale: scale,
                              child: child,
                            ),
                          );
                        },
                        child: selectedImage.isEmpty
                            ? Icon(
                          Icons.rocket_launch_rounded,
                          key: ValueKey<String>('rocket_$selectedNo'),
                          color: Colors.white,
                          size: compact ? 176 : 206,
                        )
                            : CachedNetworkImage(
                          key: ValueKey<String>(selectedImage),
                          imageUrl: selectedImage,
                          height: rocketHeight,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          fadeInDuration: Duration.zero,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.rocket_launch_rounded,
                            color: Colors.white,
                            size: compact ? 176 : 206,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // API rocket levels stay below Record with a clear gap and
          // remain above the larger platform in the Stack.
          Positioned(
            left: 0,
            top: compact ? 120 : 136,
            bottom: 34,
            width: railWidth,
            child: CustomPaint(
              painter: const _LevelRailBackdropPainter(),
              child: levels.isEmpty
                  ? const Center(
                child: Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white54,
                ),
              )
                  : ListView.separated(
                primary: false,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 5),
                itemCount: levels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, int index) {
                  final Map<String, dynamic> item = levels[index];
                  final bool active =
                      _levelKey(item) == _levelKey(_selectedLevel);
                  return _levelRailItem(
                    item: item,
                    active: active,
                    compact: compact,
                    onTap: () {
                      setState(() {
                        _selectedLevel = Map<String, dynamic>.from(item);
                        _rewardTabIndex = 0;
                      });
                    },
                  );
                },
              ),
            ),
          ),

          Positioned(
            right: 1,
            top: compact ? 100 : 114,
            bottom: 36,
            width: progressWidth,
            child: _verticalProgress(progress),
          ),

          Positioned(
            left: railWidth + 5,
            right: progressWidth + 5,
            bottom: compact ? 10.0 : 12.0,
            child: Center(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    const TextSpan(text: 'Reset countdown  '),
                    TextSpan(
                      text: controller.formatCountdown(
                        controller.remainingSeconds.value,
                      ),
                      style: const TextStyle(
                        color: Color(0xffc8ffff),
                        backgroundColor: Color(0xaa064b55),
                      ),
                    ),
                  ],
                ),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 11.5 : 13,
                  fontWeight: FontWeight.w800,
                  shadows: const <Shadow>[
                    Shadow(color: Colors.black87, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordButton() {
    return InkWell(
      onTap: _showHistorySheet,
      child: CustomPaint(
        painter: const _RecordTagPainter(),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(8, 4, 13, 5),
          child: Text(
            'Record›',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              shadows: <Shadow>[
                Shadow(color: Colors.black54, blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _levelRailItem({
    required Map<String, dynamic> item,
    required bool active,
    required bool compact,
    required VoidCallback onTap,
  }) {
    final int no = _levelNo(item);
    final String image = _levelImage(item);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: compact ? 66 : 74,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Positioned.fill(
              bottom: 15,
              child: image.isEmpty
                  ? const Icon(
                Icons.rocket_launch_rounded,
                color: Colors.white70,
                size: 37,
              )
                  : CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.contain,
                fadeInDuration: Duration.zero,
              ),
            ),
            Positioned(
              left: 1,
              right: 1,
              bottom: 0,
              height: 19,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: active
                      ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xffffd748),
                      Color(0xffe88b00),
                    ],
                  )
                      : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xff16a6a4),
                      Color(0xff08747b),
                    ],
                  ),
                  border: Border.all(
                    color: active
                        ? const Color(0xfffff0a5)
                        : const Color(0xff8ffff7),
                    width: .8,
                  ),
                  boxShadow: active
                      ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x77ffd341),
                      blurRadius: 7,
                    ),
                  ]
                      : const <BoxShadow>[],
                ),
                child: Text(
                  'LV.$no',
                  style: TextStyle(
                    color: active
                        ? const Color(0xff5a3500)
                        : Colors.white,
                    fontSize: compact ? 10.5 : 11.5,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalProgress(double percent) {
    final double safe = percent.clamp(0, 100).toDouble();

    return LayoutBuilder(
      builder: (_, BoxConstraints box) {
        final double tubeHeight = math.max(80, box.maxHeight - 38);

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: <Widget>[
            Positioned(
              top: 0,
              child: Container(
                width: 38,
                height: tubeHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      Color(0xff707b82),
                      Color(0xffd8e0e2),
                      Color(0xff646f75),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xffdceff0),
                    width: .8,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(color: Colors.black45, blurRadius: 5),
                  ],
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 30,
                    height: math.max(8, (tubeHeight - 7) * safe / 100),
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: <Color>[
                          Color(0xff16cbd0),
                          Color(0xff58edf1),
                          Color(0xffb8ffff),
                        ],
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0xaa2bf5f1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: tubeHeight * .42,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xff087c8a),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: const Color(0xffb9ffff),
                    width: .8,
                  ),
                ),
                child: Text(
                  '${safe.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Positioned(
              top: tubeHeight - 8,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: <Color>[
                      Color(0xffd7ffff),
                      Color(0xff32dbe5),
                      Color(0xff4047c9),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xff6ffff8),
                    width: 2,
                  ),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x9928e6e7),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _rewardMatchesSelectedLevel(
      Map<String, dynamic> reward,
      Map<String, dynamic> level,
      ) {
    final int wantedId = _levelId(level);
    final int wantedNo = _levelNo(level);
    final Map<String, dynamic> nested = _map(
      reward['level'] ?? reward['rocket_level'],
    );
    final int rowId = _int(
      reward['level_id'] ??
          reward['rocket_level_id'] ??
          reward['rocket_level'] ??
          nested['id'],
    );
    final int rowNo = _int(
      reward['level_no'] ?? reward['level'] ?? nested['level_no'],
    );

    final bool hasLevelMeta = rowId > 0 || rowNo > 0;
    if (!hasLevelMeta) return true;
    if (wantedId > 0 && rowId > 0) return rowId == wantedId;
    if (wantedNo > 0 && rowNo > 0) return rowNo == wantedNo;
    return false;
  }

  List<Map<String, dynamic>> _filteredGroup(
      dynamic raw,
      Map<String, dynamic> level,
      ) {
    final List<Map<String, dynamic>> rows = _list(raw);
    if (rows.isEmpty) return rows;

    bool hasLevelMeta(Map<String, dynamic> reward) {
      final Map<String, dynamic> nested = _map(
        reward['level'] ?? reward['rocket_level'],
      );
      return _int(
        reward['level_id'] ??
            reward['rocket_level_id'] ??
            reward['rocket_level'] ??
            nested['id'],
      ) >
          0 ||
          _int(
            reward['level_no'] ?? reward['level'] ?? nested['level_no'],
          ) >
              0;
    }

    final bool anyLevelMetadata = rows.any(hasLevelMeta);
    if (anyLevelMetadata) {
      return rows
          .where((row) => _rewardMatchesSelectedLevel(row, level))
          .toList(growable: false);
    }

    // A non-level-specific reward group belongs only to the current level.
    // This prevents LV.1 rewards from being repeated for LV.2/LV.3 selections.
    return _levelNo(level) == controller.levelNo.value
        ? rows
        : <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _selectedLevelRewards() {
    final Map<String, dynamic> level = _selectedLevel;
    final Map<String, dynamic> direct = _map(
      level['rewards'] ??
          level['reward_setup'] ??
          level['reward_groups'] ??
          level['reward'],
    );
    if (direct.isNotEmpty) return _normalizeRewardGroups(direct, level);

    final Map<String, dynamic> all = Map<String, dynamic>.from(controller.rewards);
    final int id = _levelId(level);
    final int no = _levelNo(level);

    for (final dynamic key in <dynamic>[
      id,
      '$id',
      no,
      '$no',
      'level_$id',
      'level_$no',
      'lv$no',
      'LV.$no',
    ]) {
      final Map<String, dynamic> nested = _map(all[key]);
      if (nested.isNotEmpty) return _normalizeRewardGroups(nested, level);
    }

    final List<Map<String, dynamic>> levelRows = _list(
      all['levels'] ??
          all['by_level'] ??
          all['reward_levels'] ??
          all['items'],
    );
    for (final Map<String, dynamic> row in levelRows) {
      final int rowId = _int(row['level_id'] ?? row['rocket_level_id'] ?? row['id']);
      final int rowNo = _int(row['level_no'] ?? row['level']);
      if ((id > 0 && rowId == id) || (no > 0 && rowNo == no)) {
        return _normalizeRewardGroups(
          _map(
            row['rewards'] ??
                row['reward_setup'] ??
                row['reward_groups'] ??
                row,
          ),
          level,
        );
      }
    }

    if (_levelNo(level) == controller.levelNo.value) {
      return _normalizeRewardGroups(all, level);
    }

    return <String, dynamic>{
      'top1': <Map<String, dynamic>>[],
      'top2': <Map<String, dynamic>>[],
      'top3': <Map<String, dynamic>>[],
      'in_room': <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> _normalizeRewardGroups(
      Map<String, dynamic> raw,
      Map<String, dynamic> level,
      ) {
    return <String, dynamic>{
      'top1': _filteredGroup(
        raw['top1'] ?? raw['top_1'] ?? raw['TOP1'],
        level,
      ),
      'top2': _filteredGroup(
        raw['top2'] ?? raw['top_2'] ?? raw['TOP2'],
        level,
      ),
      'top3': _filteredGroup(
        raw['top3'] ?? raw['top_3'] ?? raw['TOP3'],
        level,
      ),
      'in_room': _filteredGroup(
        raw['in_room'] ?? raw['inRoom'] ?? raw['room'] ?? raw['IN'],
        level,
      ),
    };
  }

  Widget _rewardPanel(double width) {
    final bool compact = width < 370;
    final Map<String, dynamic> groups = _selectedLevelRewards();
    const List<String> keys = <String>[
      'top1',
      'top2',
      'top3',
      'in_room',
    ];
    const List<String> labels = <String>[
      'TOP 1',
      'TOP 2',
      'TOP 3',
      'IN ROOM',
    ];

    final int safeIndex =
    _rewardTabIndex.clamp(0, keys.length - 1).toInt();
    final List<Map<String, dynamic>> selectedRewards =
    _list(groups[keys[safeIndex]]);

    return SizedBox(
      height: compact ? 238.0 : 262.0,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          Positioned.fill(
            top: 19,
            left: 8,
            right: 8,
            child: CustomPaint(
              painter: const _TechPanelPainter(),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 15,
                  compact ? 28 : 31,
                  compact ? 12 : 15,
                  compact ? 10 : 12,
                ),
                child: Column(
                  children: <Widget>[
                    SizedBox(
                      height: compact ? 37 : 41,
                      child: Row(
                        children: List<Widget>.generate(labels.length, (int index) {
                          final bool selected = safeIndex == index;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: index == 0 ? 0 : 2.5,
                                right: index == labels.length - 1 ? 0 : 2.5,
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  if (_rewardTabIndex == index) return;
                                  setState(() => _rewardTabIndex = index);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: selected
                                        ? const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: <Color>[
                                        Color(0xff31d7d7),
                                        Color(0xff087984),
                                      ],
                                    )
                                        : null,
                                    color: selected
                                        ? null
                                        : const Color(0xff063f4c).withOpacity(.55),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xffbaffff)
                                          : const Color(0xff3ddde5).withOpacity(.35),
                                      width: selected ? 1.2 : .8,
                                    ),
                                    boxShadow: selected
                                        ? const <BoxShadow>[
                                      BoxShadow(
                                        color: Color(0x6624f5ee),
                                        blurRadius: 9,
                                      ),
                                    ]
                                        : const <BoxShadow>[],
                                  ),
                                  child: Text(
                                    labels[index],
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: compact ? 9.6 : 11.2,
                                      fontWeight: FontWeight.w900,
                                      shadows: const <Shadow>[
                                        Shadow(color: Colors.black54, blurRadius: 3),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 10),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.linear,
                        switchOutCurve: Curves.linear,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                          final Animation<double> fade = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                            reverseCurve: Curves.easeInCubic,
                          );
                          final Animation<Offset> slide = Tween<Offset>(
                            begin: const Offset(.06, 0),
                            end: Offset.zero,
                          ).animate(fade);
                          return FadeTransition(
                            opacity: fade,
                            child: SlideTransition(position: slide, child: child),
                          );
                        },
                        child: selectedRewards.isEmpty
                            ? Container(
                          key: ValueKey<String>(
                            'empty_${_levelKey(_selectedLevel)}_$safeIndex',
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xff032e39).withOpacity(.46),
                            border: Border.all(
                              color: const Color(0xff46dce4).withOpacity(.24),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.card_giftcard_rounded,
                                color: Colors.white24,
                                size: compact ? 31 : 36,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'No ${labels[safeIndex]} reward for LV.${_levelNo(_selectedLevel)}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: compact ? 10.5 : 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                            : ListView.separated(
                          key: ValueKey<String>(
                            '${_levelKey(_selectedLevel)}_${safeIndex}_${selectedRewards.length}',
                          ),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            horizontal: selectedRewards.length == 1
                                ? math.max(
                              0.0,
                              (width -
                                  (compact ? 100 : 116) -
                                  (compact ? 54 : 66)) /
                                  2,
                            ).toDouble()
                                : 2.0,
                            vertical: 2,
                          ),
                          itemCount: selectedRewards.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(width: compact ? 8 : 10),
                          itemBuilder: (_, int index) {
                            final Map<String, dynamic> item =
                            selectedRewards[index];
                            return SizedBox(
                              width: compact ? 100 : 116,
                              child: _rewardCard(
                                item,
                                compact: compact,
                                fillWidth: true,
                                featured: safeIndex == 0 && index == 0,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: width * .25,
            right: width * .25,
            child: _sectionRibbon(
              'LV.${_levelNo(_selectedLevel)} Reward',
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyRewardCard(bool compact) {
    return CustomPaint(
      painter: const _RewardCardFramePainter(),
      child: Center(
        child: Icon(
          Icons.card_giftcard_rounded,
          color: Colors.white24,
          size: compact ? 25 : 30,
        ),
      ),
    );
  }

  Widget _rewardCard(
      Map<String, dynamic> item, {
        required bool compact,
        bool fillWidth = false,
        bool featured = false,
      }) {
    final Map<String, dynamic> ref = _map(
      item['reward'] ??
          item['reference'] ??
          item['gift'] ??
          item['asset'] ??
          item['vip_package'],
    );
    final String image = _image(
      item['image'] ??
          item['show_image'] ??
          ref['show_image'] ??
          ref['image'] ??
          ref['badge_image'],
    );
    final String amount = _text(
      item['amount'] ??
          item['quantity'] ??
          item['coin'] ??
          item['coins'] ??
          item['exp'] ??
          item['days'],
    );
    final String probability = _text(
      item['probability'] ?? item['chance'] ?? item['win_probability'],
    );

    return CustomPaint(
      painter: _RewardCardFramePainter(featured: featured),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
        child: Column(
          children: <Widget>[
            if (probability.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xffd8b52b),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(2),
                    ),
                  ),
                  child: Text(
                    '$probability% Possibility',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: const Color(0xff553a00),
                      fontSize: compact ? 7.2 : 8,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: image.isEmpty
                    ? Icon(
                  Icons.card_giftcard_rounded,
                  color: featured
                      ? const Color(0xffffdc57)
                      : const Color(0xffffd66b),
                  size: compact ? 34 : 40,
                )
                    : CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.contain,
                  fadeInDuration: Duration.zero,
                ),
              ),
            ),
            if (amount.isNotEmpty)
              Container(
                width: double.infinity,
                height: compact ? 19 : 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: featured
                      ? const LinearGradient(
                    colors: <Color>[
                      Color(0xff8c6e00),
                      Color(0xffd5aa10),
                    ],
                  )
                      : const LinearGradient(
                    colors: <Color>[
                      Color(0xff0c6571),
                      Color(0xff078896),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  amount.toUpperCase().contains('DAY')
                      ? 'X $amount'
                      : amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 9 : 10.2,
                    fontWeight: FontWeight.w900,
                    shadows: const <Shadow>[
                      Shadow(color: Colors.black54, blurRadius: 2),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _orderedRankingTopThree() {
    final List<Map<String, dynamic>> rows = controller.ranking
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList(growable: true);

    rows.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int ar = _int(a['rank'] ?? a['position'] ?? 999999);
      final int br = _int(b['rank'] ?? b['position'] ?? 999999);
      if (ar != br) return ar.compareTo(br);
      final int ac = _int(
        a['contribution_coins'] ??
            a['total_contribution'] ??
            a['total_coins'] ??
            a['coins'],
      );
      final int bc = _int(
        b['contribution_coins'] ??
            b['total_contribution'] ??
            b['total_coins'] ??
            b['coins'],
      );
      return bc.compareTo(ac);
    });

    return rows.take(3).toList(growable: false);
  }

  Map<String, dynamic> _rankingRowFor(
      List<Map<String, dynamic>> rows,
      int rank,
      ) {
    for (final Map<String, dynamic> row in rows) {
      final int rowRank = _int(row['rank'] ?? row['position']);
      if (rowRank == rank) return row;
    }

    if (rank - 1 >= 0 && rank - 1 < rows.length) {
      return rows[rank - 1];
    }
    return <String, dynamic>{};
  }

  Widget _rankingPanel() {
    final List<Map<String, dynamic>> rows = _orderedRankingTopThree();
    final double width = MediaQuery.of(context).size.width;
    final bool compact = width < 370;

    return SizedBox(
      height: compact ? 198 : 220,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          Positioned.fill(
            top: 18,
            left: 8,
            right: 8,
            child: CustomPaint(
              painter: const _TechPanelPainter(compactBottom: true),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 8 : 12,
                  compact ? 45 : 50,
                  compact ? 8 : 12,
                  compact ? 10 : 13,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: _rankingPodiumItem(
                        row: _rankingRowFor(rows, 2),
                        rank: 2,
                        compact: compact,
                        center: false,
                      ),
                    ),
                    SizedBox(width: compact ? 3 : 7),
                    Expanded(
                      child: Transform.translate(
                        offset: Offset(0, compact ? -13 : -18),
                        child: _rankingPodiumItem(
                          row: _rankingRowFor(rows, 1),
                          rank: 1,
                          compact: compact,
                          center: true,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 3 : 7),
                    Expanded(
                      child: _rankingPodiumItem(
                        row: _rankingRowFor(rows, 3),
                        rank: 3,
                        compact: compact,
                        center: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: width * .24,
            right: width * .24,
            child: _sectionRibbon('Ranking'),
          ),
        ],
      ),
    );
  }

  Widget _rankingPodiumItem({
    required Map<String, dynamic> row,
    required int rank,
    required bool compact,
    required bool center,
  }) {
    final Map<String, dynamic> user = _map(
      row['user'] ??
          row['sender'] ??
          row['contributor'] ??
          row['member'],
    );
    final String name = _text(
      user['name'] ??
          user['username'] ??
          row['name'],
      '-',
    );
    final String avatar = _image(
      user['profile_image'] ??
          user['avatar'] ??
          user['image'] ??
          row['profile_image'] ??
          row['avatar'],
    );
    final int coins = _int(
      row['contribution_coins'] ??
          row['total_contribution'] ??
          row['total_coins'] ??
          row['coins'],
    );

    final List<Color> frameColors = rank == 1
        ? const <Color>[
      Color(0xfffff5a1),
      Color(0xffffb400),
      Color(0xffff6b00),
      Color(0xfffff0a0),
    ]
        : rank == 2
        ? const <Color>[
      Color(0xffdff7ff),
      Color(0xff5ac8ff),
      Color(0xff3d68ff),
      Color(0xffe9fbff),
    ]
        : const <Color>[
      Color(0xffffe0d0),
      Color(0xffff9d6d),
      Color(0xffc66342),
      Color(0xffffe7db),
    ];

    final double avatarSize = center
        ? (compact ? 76 : 86)
        : (compact ? 61 : 69);
    final double badgeSize = center
        ? (compact ? 27 : 30)
        : (compact ? 23 : 26);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: avatarSize + 16,
          height: avatarSize + 17,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: avatarSize + 10,
                height: avatarSize + 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: frameColors),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: frameColors[1].withOpacity(.58),
                      blurRadius: center ? 18 : 12,
                      spreadRadius: center ? 2 : 1,
                    ),
                  ],
                ),
              ),
              Container(
                width: avatarSize,
                height: avatarSize,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff073844),
                  border: Border.all(
                    color: Colors.white.withOpacity(.78),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: avatar.isEmpty
                      ? Container(
                    color: const Color(0xff214d58),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person,
                      color: Colors.white38,
                      size: avatarSize * .50,
                    ),
                  )
                      : CachedNetworkImage(
                    imageUrl: avatar,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    memCacheWidth: 320,
                    memCacheHeight: 320,
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xff214d58),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: frameColors),
                    border: Border.all(color: Colors.white, width: 1.2),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black54, blurRadius: 5),
                    ],
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: rank == 2
                          ? const Color(0xff163c74)
                          : const Color(0xff6b2900),
                      fontSize: compact ? 11 : 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: center ? 4 : 2),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 10.5 : 12.2,
            fontWeight: FontWeight.w800,
            shadows: const <Shadow>[
              Shadow(color: Colors.black87, blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.monetization_on_rounded,
              color: const Color(0xffffd34e),
              size: compact ? 13 : 15,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                _compact(coins),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xffffe78d),
                  fontSize: compact ? 10.2 : 11.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionRibbon(String title) {
    return SizedBox(
      height: 38,
      child: CustomPaint(
        painter: const _RibbonPainter(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                shadows: <Shadow>[
                  Shadow(color: Colors.black87, blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footerButtons() {
    return Row(
      children: <Widget>[
        Expanded(
          child: _smallActionButton(
            icon: Icons.history_rounded,
            text: 'History',
            onTap: _showHistorySheet,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _smallActionButton(
            icon: Icons.workspace_premium_rounded,
            text: 'My Rewards',
            onTap: _showMyRewardsSheet,
          ),
        ),
      ],
    );
  }

  Widget _smallActionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(11),
          color: const Color(0xff0b5360).withOpacity(.68),
          border: Border.all(color: const Color(0xff43e7f0).withOpacity(.64)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistorySheet() async {
    await controller.fetchLaunchHistory(livestreamId: widget.livestreamId);
    Get.bottomSheet(
      _secondarySheet(
        title: 'Rocket Launch History',
        child: Obx(() {
          final List<Map<String, dynamic>> rows =
          controller.launchHistory.toList(growable: false);
          if (rows.isEmpty) {
            return const Center(
              child: Text(
                'No launch history',
                style: TextStyle(color: Colors.white60),
              ),
            );
          }
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 7),
            itemBuilder: (_, int index) {
              final Map<String, dynamic> row = rows[index];
              final Map<String, dynamic> level =
              _map(row['level'] ?? row['rocket_level']);
              final String image = _levelImage(<String, dynamic>{...level, ...row});
              final int no = _int(
                row['level_no'] ?? level['level_no'] ?? level['level'],
              );
              final String time = _text(
                row['created_at'] ?? row['timestamp'] ?? row['launched_at'],
              );
              return _secondaryRow(
                image: image,
                title: 'Rocket LV.$no',
                subtitle: time,
                fallbackIcon: Icons.rocket_launch_rounded,
              );
            },
          );
        }),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Future<void> _showMyRewardsSheet() async {
    await controller.fetchMyRewards();
    Get.bottomSheet(
      _secondarySheet(
        title: 'My Rocket Rewards',
        child: Obx(() {
          final List<Map<String, dynamic>> rows =
          controller.myRewards.toList(growable: false);
          if (rows.isEmpty) {
            return const Center(
              child: Text(
                'No Rocket rewards yet',
                style: TextStyle(color: Colors.white60),
              ),
            );
          }
          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 7),
            itemBuilder: (_, int index) {
              final Map<String, dynamic> row = rows[index];
              final String type =
              _text(row['reward_type'] ?? row['type'], 'Reward');
              final String title = _text(
                row['title'] ?? row['reward_name'] ?? row['name'],
                type,
              );
              final String time =
              _text(row['created_at'] ?? row['delivered_at']);
              final String image = _image(
                row['image'] ?? row['show_image'] ?? row['badge_image'],
              );
              return _secondaryRow(
                image: image,
                title: title,
                subtitle: '$type  •  $time',
                fallbackIcon: Icons.workspace_premium_rounded,
              );
            },
          );
        }),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _secondarySheet({
    required String title,
    required Widget child,
  }) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * .62,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xff0b2e3c), Color(0xff071622)],
          ),
          border: Border(
            top: BorderSide(color: const Color(0xff55eff8).withOpacity(.55)),
          ),
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _secondaryRow({
    required String image,
    required String title,
    required String subtitle,
    required IconData fallbackIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(.055),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: <Widget>[
          image.isEmpty
              ? CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xff116173),
            child: Icon(fallbackIcon, color: Colors.white),
          )
              : CachedNetworkImage(
            imageUrl: image,
            width: 46,
            height: 46,
            fit: BoxFit.contain,
            fadeInDuration: Duration.zero,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _RocketPlatformFallbackPainter extends CustomPainter {
  const _RocketPlatformFallbackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect outerRect = Rect.fromLTWH(
      size.width * .03,
      size.height * .18,
      size.width * .94,
      size.height * .70,
    );
    final Rect innerRect = Rect.fromLTWH(
      size.width * .15,
      size.height * .22,
      size.width * .70,
      size.height * .45,
    );

    final Paint shadow = Paint()
      ..color = Colors.black.withOpacity(.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(outerRect.shift(const Offset(0, 5)), shadow);

    final Paint outer = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0xffdce6ef),
          Color(0xff5e6877),
          Color(0xff161b23),
        ],
      ).createShader(outerRect);
    canvas.drawOval(outerRect, outer);

    canvas.drawOval(
      innerRect,
      Paint()..color = const Color(0xff202934),
    );
    canvas.drawOval(
      innerRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3, size.width * .025)
        ..color = const Color(0xffffb51f),
    );

    final Paint blueLight = Paint()
      ..color = const Color(0xff25cfff)
      ..strokeWidth = math.max(3, size.width * .018)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .16, size.height * .73),
      Offset(size.width * .34, size.height * .79),
      blueLight,
    );
    canvas.drawLine(
      Offset(size.width * .66, size.height * .79),
      Offset(size.width * .84, size.height * .73),
      blueLight,
    );

    final Paint orangeLight = Paint()
      ..color = const Color(0xffffa500)
      ..strokeWidth = math.max(2, size.width * .013)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .41, size.height * .82),
      Offset(size.width * .59, size.height * .82),
      orangeLight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RecordTagPainter extends CustomPainter {
  const _RecordTagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Path p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - 8, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - 8, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xff10c9c8), Color(0xff087a82)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xffa8ffff),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LevelRailBackdropPainter extends CustomPainter {
  const _LevelRailBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xaa09636a),
            Color(0xcc07515b),
            Color(0xdd073c48),
          ],
        ).createShader(rect),
    );

    final Paint dot = Paint()..color = const Color(0x3349ffff);
    const double gap = 7;
    for (double y = 5; y < size.height; y += gap) {
      for (double x = 4; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), .8, dot);
      }
    }

    canvas.drawLine(
      Offset(size.width - 1, 0),
      Offset(size.width - 1, size.height),
      Paint()
        ..color = const Color(0x9957f3ee)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RewardCardFramePainter extends CustomPainter {
  const _RewardCardFramePainter({this.featured = false});

  final bool featured;

  @override
  void paint(Canvas canvas, Size size) {
    const double cut = 8;
    final Path path = Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height - 4)
      ..lineTo(size.width - 4, size.height)
      ..lineTo(4, size.height)
      ..lineTo(0, size.height - 4)
      ..lineTo(0, cut)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: featured
              ? const <Color>[
            Color(0xff5f5d08),
            Color(0xff514900),
            Color(0xff263a23),
          ]
              : const <Color>[
            Color(0xff07515b),
            Color(0xff063d49),
            Color(0xff052a36),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = featured
            ? const Color(0xffe8c637)
            : const Color(0xff48dfe3),
    );

    canvas.drawLine(
      Offset(cut + 3, 3),
      Offset(size.width - cut - 3, 3),
      Paint()
        ..color = featured
            ? const Color(0x88fff17d)
            : const Color(0x775bffff)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _RewardCardFramePainter oldDelegate) =>
      oldDelegate.featured != featured;
}

class _RibbonPainter extends CustomPainter {
  const _RibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path()
      ..moveTo(10, 2)
      ..lineTo(size.width - 10, 2)
      ..lineTo(size.width - 2, 11)
      ..lineTo(size.width - 12, size.height - 5)
      ..lineTo(size.width * .65, size.height - 5)
      ..lineTo(size.width * .60, size.height - 1)
      ..lineTo(size.width * .40, size.height - 1)
      ..lineTo(size.width * .35, size.height - 5)
      ..lineTo(12, size.height - 5)
      ..lineTo(2, 11)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xff0e6268), Color(0xff08464e)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff55e6e6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) => false;
}

class _TechPanelPainter extends CustomPainter {
  const _TechPanelPainter({this.compactBottom = false});

  final bool compactBottom;

  Path _panelPath(Size size, [double inset = 0]) {
    final double w = size.width;
    final double h = size.height;
    final double cut = 12 + inset;
    final double top = 13 + inset;
    final double bottomCut = (compactBottom ? 9 : 14) + inset;

    return Path()
      ..moveTo(cut, top)
      ..lineTo(w * .22, top)
      ..lineTo(w * .25, inset + 2)
      ..lineTo(w * .75, inset + 2)
      ..lineTo(w * .78, top)
      ..lineTo(w - cut, top)
      ..lineTo(w - inset, top + 12)
      ..lineTo(w - inset, h - bottomCut)
      ..lineTo(w - bottomCut, h - inset)
      ..lineTo(bottomCut, h - inset)
      ..lineTo(inset, h - bottomCut)
      ..lineTo(inset, top + 12)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _panelPath(size);

    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xff0c6a6b),
            Color(0xff07565c),
            Color(0xff043d48),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff35e2df).withOpacity(.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff29cfd1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    canvas.drawPath(
      _panelPath(size, 6),
      Paint()
        ..color = const Color(0xff7ce5e2).withOpacity(.64)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );

    final Paint accent = Paint()
      ..color = const Color(0xff24cfd0)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(18, size.height - 3),
      Offset(size.width * .18, size.height - 3),
      accent,
    );
    canvas.drawLine(
      Offset(size.width * .82, size.height - 3),
      Offset(size.width - 18, size.height - 3),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant _TechPanelPainter oldDelegate) =>
      oldDelegate.compactBottom != compactBottom;
}

class _RocketSheetBackdropPainter extends CustomPainter {
  const _RocketSheetBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Smooth transparent-to-teal blend matching the reference: the room stays
    // visible behind the upper rocket, then the lower reward area becomes a
    // dense dark teal panel without a hard horizontal edge.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x00000000),
            Color(0x00000000),
            Color(0x00000000),
            Color(0x5A004B53),
            Color(0xD9003B44),
            Color(0xF8002B34),
            Color(0xFF001C26),
          ],
          stops: <double>[0, .16, .25, .38, .51, .68, 1],
        ).createShader(rect),
    );

    // Cyan/green launch glow centered behind the platform.
    final Rect glowRect = Rect.fromLTWH(
      size.width * .03,
      size.height * .19,
      size.width * .94,
      size.height * .43,
    );
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, .25),
          radius: .72,
          colors: <Color>[
            const Color(0xff75fff2).withOpacity(.20),
            const Color(0xff20d8cb).withOpacity(.15),
            const Color(0xff0a8f91).withOpacity(.08),
            Colors.transparent,
          ],
        ).createShader(glowRect),
    );

    final Rect rocketWashRect = Rect.fromLTWH(
      0,
      size.height * .23,
      size.width,
      size.height * .31,
    );
    canvas.drawRect(
      rocketWashRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x006AFFF4),
            Color(0x1840E8DA),
            Color(0x1200A7A3),
            Color(0x0000A7A3),
          ],
          stops: <double>[0, .28, .70, 1],
        ).createShader(rocketWashRect),
    );

    // Low-opacity futuristic dots only in the lower half.
    final Paint dot = Paint()..color = const Color(0x1f56f2e9);
    final double startY = size.height * .36;
    for (double y = startY; y < size.height; y += 16) {
      for (double x = 8; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }

    final Paint line = Paint()
      ..color = const Color(0x2251e7e4)
      ..strokeWidth = .7;
    canvas.drawLine(
      Offset(0, size.height * .57),
      Offset(size.width, size.height * .57),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _RocketSheetBackdropPainter oldDelegate) =>
      false;
}

class AudioRoomGameHubSheet extends StatelessWidget {
  const AudioRoomGameHubSheet({
    super.key,
    required this.livestreamId,
  });

  final int livestreamId;

  static Future<void> show({required int livestreamId}) async {
    Get.bottomSheet(
      AudioRoomGameHubSheet(livestreamId: livestreamId),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        decoration: const BoxDecoration(
          color: Color(0xff10131f),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Room Features',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: _HubCard(
                    title: 'Room Support',
                    icon: Icons.workspace_premium_rounded,
                    colors: const <Color>[Color(0xff075a3f), Color(0xff0dcc8b)],
                    onTap: () async {
                      Get.back();
                      await RoomSupportWeeklySheet.show(
                        livestreamId: livestreamId,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HubCard(
                    title: 'Rocket',
                    icon: Icons.rocket_launch_rounded,
                    colors: const <Color>[Color(0xff0e5670), Color(0xff14b6d4)],
                    onTap: () async {
                      Get.back();
                      await RocketGameEventSheet.show(
                        livestreamId: livestreamId,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 118,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: colors),
          border: Border.all(color: const Color(0xff66f4ff)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 42),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
