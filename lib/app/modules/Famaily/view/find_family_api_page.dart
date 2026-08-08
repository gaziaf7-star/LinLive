import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Controller/FamilyConroller.dart';
import '../Models/family_models.dart';
import '../Widgets/family_common_widgets.dart';
import '../Widgets/family_shimmer.dart';
import 'create_family_api_page.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class FindFamilyApiPage extends StatefulWidget {
  const FindFamilyApiPage({super.key});

  @override
  State<FindFamilyApiPage> createState() => _FindFamilyApiPageState();
}

class _FindFamilyApiPageState extends State<FindFamilyApiPage>
    with TickerProviderStateMixin {
  final FamilyController controller = Get.put(Familyconroller(), permanent: true);

  late final TabController tabController;
  late final AnimationController _bgController;

  static const Color _primary = Color(0xFF190522);
  static const Color _secondary = Color(0xFF3B072F);
  static const Color _accent = Color(0xFFFF3D8B);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _gold1 = Color(0xFFFFC400);
  static const Color _gold2 = Color(0xFFFFF238);
  static const Color _pageBg = Color(0xFFFFF7FD);
  static const Color _textDark = Color(0xFF211625);
  static const Color _muted = Color(0xFF827484);

  @override
  void initState() {
    super.initState();

    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(() {
      if (!tabController.indexIsChanging) {
        controller.changeSort(tabController.index == 0 ? 'ranking' : 'top');
      }
    });

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    tabController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  double _s(BuildContext context, double value) {
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 390.0).clamp(0.86, 1.18);
    return value * scale;
  }

  @override
  Widget build(BuildContext context) {
    final r = FamilyUi.r;

    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          _animatedPageBackground(context),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r(context, 14)),
                  child: _searchBox(context),
                ),
                SizedBox(height: r(context, 12)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: r(context, 14)),
                  child: _tabBox(context),
                ),
                SizedBox(height: r(context, 8)),
                Expanded(
                  child: Obx(() {
                    if (controller.listStatus.value == FamilyPageStatus.loading) {
                      return const FamilyListShimmer();
                    }
                    if (controller.listStatus.value == FamilyPageStatus.error) {
                      return _empty(
                        context,
                        controller.errorMessage.value,
                        retry: () => controller.loadFamilyList(refresh: true),
                      );
                    }
                    if (controller.familyList.isEmpty) {
                      return _empty(context, ('No family found').appTr);
                    }

                    return RefreshIndicator(
                      color: _accent,
                      backgroundColor: Colors.white,
                      onRefresh: () => controller.loadFamilyList(refresh: true),
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                            controller.loadFamilyList();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            r(context, 12),
                            r(context, 8),
                            r(context, 12),
                            r(context, 22),
                          ),
                          itemCount: controller.familyList.length +
                              (controller.hasMore.value ? 1 : 0),
                          separatorBuilder: (_, __) => SizedBox(height: r(context, 12)),
                          itemBuilder: (_, index) {
                            if (index >= controller.familyList.length) {
                              return Padding(
                                padding: EdgeInsets.all(r(context, 14)),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: _accent,
                                  ),
                                ),
                              );
                            }
                            return _familyCard(context, controller.familyList[index]);
                          },
                        ),
                      ),
                    );
                  }),
                ),
                _createFamilyOption(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedPageBackground(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        final v = _bgController.value;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFEFF8),
                    Color(0xFFFFFFFF),
                    Color(0xFFFFF7FD),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -_s(context, 80) + (v * 22),
              right: -_s(context, 85) + (v * 10),
              child: _softCircle(_s(context, 220), _accent.withOpacity(.16)),
            ),
            Positioned(
              top: _s(context, 210) - (v * 28),
              left: -_s(context, 118),
              child: _softCircle(_s(context, 240), _purple.withOpacity(.12)),
            ),
            Positioned(
              bottom: -_s(context, 88),
              right: _s(context, 12) + (v * 24),
              child: _softCircle(_s(context, 190), _gold1.withOpacity(.10)),
            ),
            Positioned(
              top: _s(context, 140) + (v * 10),
              right: _s(context, 28),
              child: _familyPattern(context, Icons.favorite_rounded, .06),
            ),
            Positioned(
              top: _s(context, 315) - (v * 12),
              left: _s(context, 24),
              child: _familyPattern(context, Icons.groups_2_rounded, .055),
            ),
            Positioned(
              bottom: _s(context, 130) + (v * 16),
              right: _s(context, 36),
              child: _familyPattern(context, Icons.home_work_rounded, .05),
            ),
          ],
        );
      },
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _familyPattern(BuildContext context, IconData icon, double opacity) {
    return Icon(
      icon,
      size: _s(context, 82),
      color: _secondary.withOpacity(opacity),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final r = FamilyUi.r;

    return Container(
      margin: EdgeInsets.fromLTRB(
        r(context, 12),
        r(context, 8),
        r(context, 12),
        r(context, 14),
      ),
      padding: EdgeInsets.fromLTRB(
        r(context, 10),
        r(context, 10),
        r(context, 12),
        r(context, 10),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, _secondary, _accent],
        ),
        borderRadius: BorderRadius.circular(r(context, 26)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: Get.back,
            borderRadius: BorderRadius.circular(r(context, 16)),
            child: Container(
              width: r(context, 42),
              height: r(context, 42),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.14),
                borderRadius: BorderRadius.circular(r(context, 16)),
                border: Border.all(color: Colors.white.withOpacity(.16)),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: r(context, 18),
              ),
            ),
          ),
          SizedBox(width: r(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ('Find Family').appTr,
                  style: TextStyle(
                    fontSize: r(context, 20),
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: r(context, 5)),
                Text(
                  ('Search and join your best family').appTr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: r(context, 12),
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(.72),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: r(context, 42),
            height: r(context, 42),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_gold1, _gold2]),
              boxShadow: [
                BoxShadow(
                  color: _gold1.withOpacity(.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.search_rounded,
              color: _textDark,
              size: r(context, 23),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox(BuildContext context) {
    final r = FamilyUi.r;

    return Container(
      height: r(context, 48),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(r(context, 18)),
        border: Border.all(color: Colors.white.withOpacity(.90)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        onChanged: controller.updateSearch,
        cursorColor: _accent,
        style: TextStyle(
          fontSize: r(context, 13.8),
          fontWeight: FontWeight.w800,
          color: _textDark,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: r(context, 22),
            color: _secondary.withOpacity(.58),
          ),
          hintText: ('Search family name or ID').appTr,
          hintStyle: TextStyle(
            fontSize: r(context, 13),
            fontWeight: FontWeight.w700,
            color: const Color(0xffA796AA),
          ),
          contentPadding: EdgeInsets.only(top: r(context, 13), right: r(context, 12)),
        ),
      ),
    );
  }

  Widget _tabBox(BuildContext context) {
    final r = FamilyUi.r;

    return Container(
      height: r(context, 48),
      padding: EdgeInsets.all(r(context, 5)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.90),
        borderRadius: BorderRadius.circular(r(context, 18)),
        border: Border.all(color: const Color(0xFFF0E0F2)),
        boxShadow: [
          BoxShadow(
            color: _secondary.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TabBar(
        controller: tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(r(context, 14)),
          gradient: const LinearGradient(colors: [_primary, _secondary, _accent]),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(.18),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: _muted,
        labelStyle: TextStyle(
          fontSize: r(context, 12.8),
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: r(context, 12.5),
          fontWeight: FontWeight.w800,
        ),
        tabs:  [
          Tab(text: ('Recommended').appTr),
          Tab(text: ('Top Ranking').appTr),
        ],
      ),
    );
  }

  Widget _createFamilyOption(BuildContext context) {
    final r = FamilyUi.r;

    return Obx(() {
      final coins = controller.userAvailableCoins;
      final canCreate = controller.canCreateFamily;
      final hasFamily = controller.hasFamily;

      return Container(
        padding: EdgeInsets.fromLTRB(
          r(context, 12),
          r(context, 10),
          r(context, 12),
          r(context, 12),
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.92),
          boxShadow: [
            BoxShadow(
              color: _secondary.withOpacity(.10),
              blurRadius: 22,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            if (hasFamily) {

              return;
            }
            if (!canCreate) {
              Get.snackbar(
                ('Not Enough Coins').appTr,
                ('You need 200,000 coins to create a family.').appTr,
                snackPosition: SnackPosition.BOTTOM,
              );
              return;
            }
            Get.to(() => const CreateFamilyApiPage());
          },
          borderRadius: BorderRadius.circular(r(context, 18)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: r(context, 76),
            padding: EdgeInsets.symmetric(horizontal: r(context, 12)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r(context, 18)),
              gradient: canCreate
                  ? const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [_primary, _secondary, _accent],
              )
                  : const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFFFF4FB), Color(0xFFFFFFFF)],
              ),
              border: Border.all(
                color: canCreate ? Colors.white.withOpacity(.10) : const Color(0xFFF0E0F2),
              ),
              boxShadow: [
                BoxShadow(
                  color: canCreate ? _accent.withOpacity(.22) : _secondary.withOpacity(.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: r(context, 47),
                  height: r(context, 47),
                  decoration: BoxDecoration(
                    color: canCreate ? Colors.white.withOpacity(.15) : _secondary.withOpacity(.08),
                    borderRadius: BorderRadius.circular(r(context, 15)),
                    border: Border.all(
                      color: canCreate ? Colors.white.withOpacity(.14) : _secondary.withOpacity(.06),
                    ),
                  ),
                  child: Icon(
                    Icons.add_home_work_rounded,
                    color: canCreate ? Colors.white : _secondary,
                    size: r(context, 25),
                  ),
                ),
                SizedBox(width: r(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ('Create Family').appTr,
                        style: TextStyle(
                          fontSize: r(context, 15.8),
                          fontWeight: FontWeight.w900,
                          color: canCreate ? Colors.white : _textDark,
                        ),
                      ),
                      SizedBox(height: r(context, 4)),
                      Text(
                        hasFamily
                            ? ('You already have a family').appTr: ('Your coins: ${FamilyUi.compact(coins)}').appTr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: r(context, 11.8),
                          fontWeight: FontWeight.w800,
                          color: canCreate ? Colors.white.withOpacity(.80) : _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: r(context, 35),
                  padding: EdgeInsets.symmetric(horizontal: r(context, 10)),
                  decoration: BoxDecoration(
                    gradient: canCreate
                        ? const LinearGradient(colors: [_gold1, _gold2])
                        : const LinearGradient(colors: [_primary, _secondary]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: canCreate ? _gold1.withOpacity(.26) : _secondary.withOpacity(.14),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monetization_on_rounded,
                        color: canCreate ? _textDark : _gold1,
                        size: r(context, 16),
                      ),
                      SizedBox(width: r(context, 4)),
                      Text(
                        '200,000',
                        style: TextStyle(
                          fontSize: r(context, 12.5),
                          fontWeight: FontWeight.w900,
                          color: canCreate ? _textDark : Colors.white,
                        ),
                      ),
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

  Widget _familyCard(BuildContext context, FamilyModel family) {
    final r = FamilyUi.r;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: EdgeInsets.all(r(context, 1.2)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r(context, 19)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(.95),
              _accent.withOpacity(.18),
              _primary.withOpacity(.10),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _secondary.withOpacity(.075),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Container(

          padding: EdgeInsets.symmetric(
            horizontal: r(context, 11),
            vertical: r(context, 10),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.94),
            borderRadius: BorderRadius.circular(r(context, 18)),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: EdgeInsets.all(r(context, 3)),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(r(context, 18)),
                      gradient: const LinearGradient(colors: [_gold1, _accent, _purple]),
                    ),
                    child: FamilyNetworkImage(
                      url: family.logoUrl,
                      size: r(context, 60),
                      radius: r(context, 15),
                    ),
                  ),
                  Positioned(
                    right: -r(context, 5),
                    bottom: -r(context, 5),
                    child: Container(
                      width: r(context, 25),
                      height: r(context, 25),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [_gold1, _gold2]),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${family.levelNo}',
                        style: TextStyle(
                          color: _textDark,
                          fontSize: r(context, 10.2),
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: r(context, 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      family.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: r(context, 14.6),
                        color: _textDark,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: r(context, 8)),
                    Wrap(
                      spacing: r(context, 7),
                      runSpacing: r(context, 6),
                      children: [
                        _infoPill(
                          context,
                          icon: Icons.military_tech_rounded,
                          text: ('Lv. ${family.levelNo}').appTr,
                        ),
                        _infoPill(
                          context,
                          icon: Icons.groups_rounded,
                          text: family.memberText,
                        ),
                      ],
                    ),
                    SizedBox(height: r(context, 8)),
                    Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: _accent, size: r(context, 15)),
                        SizedBox(width: r(context, 4)),
                        Text(
                          '${FamilyUi.compact(family.points)} ',
                          style: TextStyle(
                            fontSize: r(context, 11.7),
                            color: _textDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          ('Points').appTr,
                          style: TextStyle(
                            fontSize: r(context, 10.8),
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: r(context, 8)),
              Obx(
                    () => InkWell(
                  onTap: controller.isActionLoading.value || family.isPending
                      ? null
                      : () => controller.joinFamily(family.id),
                  borderRadius: BorderRadius.circular(r(context, 12)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: r(context, 38),
                    padding: EdgeInsets.symmetric(horizontal: r(context, 14)),
                    decoration: BoxDecoration(
                      gradient: family.isPending
                          ? const LinearGradient(colors: [Color(0xffE8DFF1), Color(0xffF4ECF6)])
                          : const LinearGradient(colors: [_primary, _secondary, _accent]),
                      borderRadius: BorderRadius.circular(r(context, 12)),
                      boxShadow: family.isPending
                          ? []
                          : [
                        BoxShadow(
                          color: _accent.withOpacity(.20),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      family.isPending ? ('Pending').appTr: ('Apply').appTr,
                      style: TextStyle(
                        fontSize: r(context, 12),
                        color: family.isPending ? _secondary : Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPill(
      BuildContext context, {
        required IconData icon,
        required String text,
      }) {
    final r = FamilyUi.r;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: r(context, 8),
        vertical: r(context, 4),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3FB),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFF0E0F2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _secondary, size: r(context, 12.5)),
          SizedBox(width: r(context, 4)),
          Text(
            text,
            style: TextStyle(
              fontSize: r(context, 10.8),
              color: _secondary,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, String text, {VoidCallback? retry}) {
    final r = FamilyUi.r;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(r(context, 22)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(r(context, 22)),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.92),
            borderRadius: BorderRadius.circular(r(context, 24)),
            border: Border.all(color: const Color(0xFFF0E0F2)),
            boxShadow: [
              BoxShadow(
                color: _secondary.withOpacity(.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: r(context, 58),
                height: r(context, 58),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_primary, _secondary, _accent]),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(.18),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Icon(Icons.groups_2_rounded, color: Colors.white, size: r(context, 29)),
              ),
              SizedBox(height: r(context, 12)),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                  fontSize: r(context, 14),
                ),
              ),
              if (retry != null) ...[
                SizedBox(height: r(context, 14)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(r(context, 13)),
                    ),
                  ),
                  onPressed: retry,
                  child:  Text(('Try Again').appTr),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
