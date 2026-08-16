import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meetlivepro/app/localization/app_localizer.dart';

import '../../controllers/svip_controller.dart';
import '../vipModel.dart';

class SvipSettingsPage extends StatefulWidget {
  final VipLevel? level;
  final List<VipLevel> levels;
  final SvipController? controller;

  const SvipSettingsPage({
    super.key,
    this.level,
    this.levels = const <VipLevel>[],
    this.controller,
  });

  @override
  State<SvipSettingsPage> createState() => _SvipSettingsPageState();
}

class _SvipSettingsPageState extends State<SvipSettingsPage> {
  late final SvipController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? Get.find<SvipController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.reloadCurrentUserVip(silent: true);
    });
  }

  double _scale(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // 390 logical pixels is the reference width of the supplied design.
    // The clamp keeps the same visual proportions on narrow and wide phones
    // without making controls too small or oversized.
    final widthScale = size.width / 390;
    final heightScale = size.height / 844;
    return math
        .min(widthScale, math.max(.90, heightScale))
        .clamp(.86, 1.16)
        .toDouble();
  }

  VipLevel? _levelByNumber(int levelNo) {
    for (final item in widget.levels) {
      if (item.levelNo == levelNo) return item;
    }
    return controller.levelByNumber(levelNo);
  }

  String _badgeLabel(int levelNo) {
    final level = _levelByNumber(levelNo);
    final title = level?.displayTitle.trim() ?? '';
    if (title.isNotEmpty) return title.toUpperCase();
    return 'SVIP$levelNo';
  }

  int _levelForSettingKey(String key) {
    switch (key) {
      case 'hide_visitor_records':
        return 2;
      case 'hide_online_status':
        return 4;
      case 'avoid_disturbing':
        return 5;
      case 'is_enabled':
        return controller.currentVip.value?.vipLevelNo ??
            widget.level?.levelNo ??
            1;
      default:
        return widget.level?.levelNo ?? 1;
    }
  }

  _SvipBadgeData _badgeForLevel(int levelNo) {
    return _SvipBadgeData(
      label: _badgeLabel(levelNo),
      level: _levelByNumber(levelNo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _scale(context);
    final topPadding = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xfff3f3f3),
      body: Column(
        children: [
          Container(
            height: topPadding + (58 * s),
            color: Colors.white,
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: InkWell(
                      onTap: Get.back,
                      borderRadius: BorderRadius.circular(100),
                      child: SizedBox(
                        height: 48 * s,
                        width: 48 * s,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: const Color(0xff222222),
                          size: 24 * s,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    ('${controller.sectionLabel} Settings').appTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: const Color(0xff050505),
                      fontSize: 20 * s,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Obx(() {
                final current = controller.currentVip.value;
                final screen = controller.settingsScreen.value ??
                    current?.settingsScreen;

                if (controller.isMyVipLoading.value && current == null) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xff39d66f),
                      strokeWidth: 2.4,
                    ),
                  );
                }

                if (current == null || !current.isActive) {
                  return _NoActiveVip(scale: s);
                }

                final permissionSwitches = controller.permissionSwitchItems;

                return RefreshIndicator(
                  color: const Color(0xff39d66f),
                  onRefresh: () => controller.reloadCurrentUserVip(),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    children: [
                      // ✅ ONLY VIP PRIVILEGES:
                      // Backend/API `permission_switches`-e je item gula ashbe
                      // sudhu oi gula-i ei page-e show hobe.
                      _SettingsSectionHeader(
                        title: ('VIP Privileges').appTr,
                        scale: s,
                      ),

                      if (permissionSwitches.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * s,
                            vertical: 36 * s,
                          ),
                          child: Text(
                            ('No VIP privileges available').appTr,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.roboto(
                              color: const Color(0xff888888),
                              fontSize: 14.5 * s,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        ...permissionSwitches.map(
                              (item) => _apiPermissionSwitchTile(item, s),
                        ),

                      SizedBox(height: 22 * s),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _apiSwitchTile(
      VipSettingSwitchItem item,
      double scale, {
        bool isMaster = false,
      }) {
    final levelNo = _levelForSettingKey(item.key);
    final saving = controller.isSettingSaving(item.key);
    final anySaving = controller.isSettingsLoading.value;
    final value = controller.settingValue(item.key);

    return _SettingsSwitchTile(
      scale: scale,
      badges: [_badgeForLevel(levelNo)],
      title: item.label.appTr,
      description: item.description.appTr,
      value: value,
      loading: saving,
      enabled: !anySaving,
      onChanged: (next) {
        controller.updateVipSetting(key: item.key, value: next);
      },
      emphasize: isMaster,
    );
  }


  Widget _apiPermissionSwitchTile(
      Map<String, dynamic> item,
      double scale,
      ) {
    final key = VipHelpers.toStr(item['key']).trim();
    if (key.isEmpty) return const SizedBox.shrink();

    final label = VipHelpers.firstStr(
      item,
      ['label', 'title'],
      fallback: key.replaceAll('_', ' '),
    );
    final description = VipHelpers.firstStr(
      item,
      ['description', 'subtitle', 'text'],
    );
    final icon = VipHelpers.toStr(item['icon']).trim();

    final levelNo = controller.currentVip.value?.vipLevelNo ??
        widget.level?.levelNo ??
        1;
    final saving = controller.isSettingSaving(key);
    final anySaving = controller.isSettingsLoading.value;
    final value = controller.settingValue(key);

    return _SettingsSwitchTile(
      scale: scale,
      badges: [_badgeForLevel(levelNo)],
      title: icon.isEmpty ? label.appTr : '$icon ${label.appTr}',
      description: description.appTr,
      value: value,
      loading: saving,
      enabled: !anySaving,
      onChanged: (next) {
        controller.updateVipSetting(key: key, value: next);
      },
    );
  }
}

class _NoActiveVip extends StatelessWidget {
  final double scale;

  const _NoActiveVip({required this.scale});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 28 * scale),
      children: [
        SizedBox(height: 130 * scale),
        Icon(
          Icons.workspace_premium_outlined,
          size: 68 * scale,
          color: const Color(0xffb8b8b8),
        ),
        SizedBox(height: 18 * scale),
        Text(
          ('No active VIP').appTr,
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            color: const Color(0xff222222),
            fontSize: 20 * scale,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          ('Purchase or activate VIP before changing SVIP settings.').appTr,
          textAlign: TextAlign.center,
          style: GoogleFonts.roboto(
            color: const Color(0xff777777),
            fontSize: 14.5 * scale,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  final double scale;

  const _SettingsSectionHeader({required this.title, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Container(

      height: 48 * scale,

      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 16 * scale),
      color: const Color(0xffeeeeee),
      child: Text(
        title,
        style: GoogleFonts.roboto(
          color: const Color(0xff101010),
          fontSize: 15.5 * scale,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final double scale;
  final List<_SvipBadgeData> badges;
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final bool loading;
  final bool emphasize;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.scale,
    required this.badges,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.loading = false,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : .72,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: emphasize ? 108 * scale : 104 * scale),
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          16 * scale,
          15 * scale,
          14 * scale,
          14 * scale,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _BadgeRow(badges: badges, scale: scale),

                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: const Color(0xff222222),
                            fontSize: 17.5 * scale,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 7 * scale),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: const Color(0xff777777),
                      fontSize: 15.5 * scale,
                      fontWeight: FontWeight.w400,
                      height: 1.18,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10 * scale),
            Stack(
              alignment: Alignment.center,
              children: [
                _SvipSmoothSwitch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  scale: scale,
                ),
                if (loading)
                  SizedBox(
                    height: 15 * scale,
                    width: 15 * scale,
                    child: const CircularProgressIndicator(
                      strokeWidth: 1.7,
                      color: Color(0xff1d9f4c),
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

class _SettingsLinkTile extends StatelessWidget {
  final double scale;
  final List<_SvipBadgeData> badges;
  final String title;
  final bool showBottomLine;
  final VoidCallback? onTap;

  const _SettingsLinkTile({
    required this.scale,
    required this.badges,
    required this.title,
    this.showBottomLine = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap ?? () {},
        child: Container(
          height: 72 * scale,
          padding: EdgeInsets.only(left: 16 * scale, right: 18 * scale),
          decoration: BoxDecoration(
            border: showBottomLine
                ? Border(
              bottom: BorderSide(
                color: Colors.black.withOpacity(.035),
                width: .7,
              ),
            )
                : null,
          ),
          child: Row(
            children: [
              _BadgeRow(badges: badges, scale: scale),
              SizedBox(width: 12 * scale),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: const Color(0xff222222),
                    fontSize: 17 * scale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xffcfcfcf),
                size: 30 * scale,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final List<_SvipBadgeData> badges;
  final double scale;

  const _BadgeRow({required this.badges, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(badges.length, (index) {
        return Padding(
          padding: EdgeInsets.only(
            right: index == badges.length - 1 ? 0 : 5 * scale,
          ),
          child: _SvipBadge(data: badges[index], scale: scale),
        );
      }),
    );
  }
}

class _SvipBadgeData {
  final String label;
  final VipLevel? level;

  const _SvipBadgeData({required this.label, this.level});
}

class _SvipBadge extends StatelessWidget {
  final _SvipBadgeData data;
  final double scale;

  const _SvipBadge({required this.data, required this.scale});

  @override
  Widget build(BuildContext context) {
    // The settings design uses the VIP title artwork on the left side.
    // Prefer title_image_url exactly as returned by the VIP level API.
    final url = _titleImageUrl(data.level);
    final colors = _badgeColors(data.label);

    return RepaintBoundary(
      child: SizedBox(
        height: 33 * scale,
        width: 60 * scale,
        child: url.isEmpty
            ? _FallbackBadge(label: data.label, colors: colors, scale: scale)
            : AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              height: 33 * scale,
              width: 50 * scale,
              child: Image.network(
                url,
                key: ValueKey<String>(url),
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
                isAntiAlias: true,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _BadgeShimmer(
                    borderRadius: 8 * scale,
                    baseColor: colors.first.withOpacity(.20),
                    highlightColor: Colors.white.withOpacity(.45),
                  );
                },
                errorBuilder: (_, __, ___) => _FallbackBadge(
                  label: data.label,
                  colors: colors,
                  scale: scale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  final String label;
  final List<Color> colors;
  final double scale;

  const _FallbackBadge({
    required this.label,
    required this.colors,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 33 * scale,
      width: 100 * scale,
      padding: EdgeInsets.symmetric(horizontal: 6 * scale),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18 * scale),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(.76), width: .8),
        boxShadow: [
          BoxShadow(color: colors.last.withOpacity(.24), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white.withOpacity(.95),
            size: 14 * scale,
          ),
          SizedBox(width: 3 * scale),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                color: Colors.white,
                fontSize: 13.2 * scale,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SvipSmoothSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double scale;

  const _SvipSmoothSwitch({
    required this.value,
    required this.onChanged,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 32 * scale,
        width: 58 * scale,
        padding: EdgeInsets.all(4 * scale),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24 * scale),
          color: value ? const Color(0xff39d66f) : const Color(0xffe4e4e4),
          boxShadow: value
              ? [
            BoxShadow(
              color: const Color(0xff2fc467).withOpacity(.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ]
              : const [],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            height: 24 * scale,
            width: 24 * scale,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeShimmer extends StatefulWidget {
  final double borderRadius;
  final Color baseColor;
  final Color highlightColor;

  const _BadgeShimmer({
    required this.borderRadius,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_BadgeShimmer> createState() => _BadgeShimmerState();
}

class _BadgeShimmerState extends State<_BadgeShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.max(1.0, constraints.maxWidth);
          final shimmerWidth = width * .45;
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dx =
                  (width + shimmerWidth) * _controller.value - shimmerWidth;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: widget.baseColor),
                  Positioned(
                    left: dx,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: shimmerWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.highlightColor.withOpacity(0),
                            widget.highlightColor.withOpacity(.55),
                            widget.highlightColor.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

String _titleImageUrl(VipLevel? level) {
  if (level == null) return '';

  // The requested source is title_image/title_image_url.
  // It is checked before the separate preview field so the exact API artwork
  // appears in every settings row.
  final titleUrl = level.titleImageUrl.trim();
  if (titleUrl.isNotEmpty && VipHelpers.ext(titleUrl) != 'svga') {
    return titleUrl;
  }

  final titlePreviewUrl = level.titleImageShowImageUrl.trim();
  if (titlePreviewUrl.isNotEmpty &&
      VipHelpers.ext(titlePreviewUrl) != 'svga') {
    return titlePreviewUrl;
  }

  // Safe backward-compatible fallback for older VIP records that do not yet
  // contain a title image.
  final badgePreviewUrl = level.badgeImageShowImageUrl.trim();
  if (badgePreviewUrl.isNotEmpty &&
      VipHelpers.ext(badgePreviewUrl) != 'svga') {
    return badgePreviewUrl;
  }

  final badgeUrl = level.badgeImageUrl.trim();
  if (badgeUrl.isNotEmpty && VipHelpers.ext(badgeUrl) != 'svga') {
    return badgeUrl;
  }

  return '';
}

List<Color> _badgeColors(String label) {
  final number = int.tryParse(
    RegExp(r'\d+').firstMatch(label)?.group(0) ?? '',
  ) ??
      0;
  switch (number) {
    case 1:
      return const [Color(0xff9e7168), Color(0xff633e36)];
    case 2:
      return const [Color(0xff8b45df), Color(0xff4f178e)];
    case 3:
      return const [Color(0xff48b8ff), Color(0xff1368be)];
    case 4:
      return const [Color(0xffffb22f), Color(0xffa65d00)];
    case 5:
      return const [Color(0xffff6037), Color(0xffb71b08)];
    case 6:
      return const [Color(0xff58ce71), Color(0xff147d38)];
    case 7:
      return const [Color(0xff65c8ff), Color(0xff1873b5)];
    case 8:
      return const [Color(0xffd85cff), Color(0xff7b1aa6)];
    case 9:
      return const [Color(0xffffb41f), Color(0xffb51c09)];
    default:
      return const [Color(0xfff95a6e), Color(0xffa82235)];
  }
}