import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/cp_data_controller.dart';
import 'anovescryCpPage.dart';
import 'couple_chat_router.dart';
import 'cpCounterPage.dart';
import 'couple_profile_page.dart';
import 'cp_level_page.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class CpHomePage extends StatefulWidget {
  const CpHomePage({
    super.key,
    this.boyImage,
    this.girlImage,
  });

  final String? boyImage;
  final String? girlImage;

  @override
  State<CpHomePage> createState() => _CpHomePageState();
}

class _CpHomePageState extends State<CpHomePage>
    with SingleTickerProviderStateMixin {
  final CpDataController cpController = Get.isRegistered<CpDataController>()
      ? Get.find<CpDataController>()
      : Get.put(CpDataController());

  late final AnimationController _heartController;
  late final List<_HeartParticle> _particles;

  @override
  void initState() {
    super.initState();

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    final random = math.Random(20);
    _particles = List.generate(24, (index) {
      return _HeartParticle(
        dx: random.nextDouble(),
        size: 10 + random.nextDouble() * 16,
        speed: .7 + random.nextDouble() * .8,
        phase: random.nextDouble(),
        opacity: .25 + random.nextDouble() * .55,
        color: [
          const Color(0xffff4f8b),
          const Color(0xffff7aa8),
          const Color(0xffff5e5e),
          const Color(0xffffb3c9),
        ][random.nextInt(4)],
      );
    });

    Future.microtask(() {
      _refreshCpHome(showLoader: false);
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _refreshCpHome({bool showLoader = true}) async {
    await Future.wait([
      cpController.fetchCpData(showLoader: showLoader),
      cpController.fetchCpLevelData(showLoader: showLoader),
    ]);
  }

  void _openPageWithAnimation(Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 430),
        reverseTransitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.10, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );

          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final headerHeight = (width * .86).clamp(290.0, 370.0).toDouble();

    return Obx(() {
      final cp = cpController.acceptedCp;
      final isLoading = cpController.isLoading.value && cp == null;

      return Scaffold(
        backgroundColor: const Color(0xfffff7fb),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () => _refreshCpHome(),
                  child: SingleChildScrollView(
                    // physics: const AlwaysScrollableScrollPhysics(
                    //   parent: BouncingScrollPhysics(),
                    // ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          SizedBox(height: headerHeight - 26),
                          _buildBodyPanel(
                            width,
                            height,
                            headerHeight,
                            cp,
                            isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Header top layer e rakha holo,
                // jate couple profile image click thik moto kaj kore.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildHeader(width, headerHeight, cp, isLoading),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHeader(
      double width,
      double headerHeight,
      CpRequestModel? cp,
      bool isLoading,
      ) {
    final title = cp == null ? 'You & Me' : cp.togetherTitle;
    final subtitle = isLoading
        ? 'Loading CP Data...'
        : cp == null
        ? 'Together Forever ❤'
        : '${cp.daysTogether} Days Together • ${cp.sinceFullDate}';

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff190a35),
                  Color(0xff35105d),
                  Color(0xff74205f),
                  Color(0xff331155),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _StarPainter(),
            ),
          ),
          AnimatedBuilder(
            animation: _heartController,
            builder: (context, _) {
              return Stack(
                children: _particles.map((p) {
                  final t = (_heartController.value * p.speed + p.phase) % 1;
                  final x = p.dx * width + math.sin(t * math.pi * 2) * 18;
                  final y = headerHeight * (1.04 - t * 1.12);
                  final opacity = (math.sin(t * math.pi) * p.opacity)
                      .clamp(0.0, 1.0)
                      .toDouble();

                  return Positioned(
                    left: x,
                    top: y,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.rotate(
                        angle: math.sin(t * math.pi * 2) * .25,
                        child: Icon(
                          Icons.favorite,
                          size: p.size,
                          color: p.color,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, .05),
                radius: .75,
                colors: [
                  const Color(0xffff5faf).withOpacity(.30),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap:(){
                          Get.back();
            },
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 25,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: Colors.pink.shade200,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                           Text(
                            ('Our CP Home').appTr,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  InkWell(
                    borderRadius: BorderRadius.circular(120),
                    onTap: () {
                      debugPrint('✅ CP profile image clicked');
                      _openPageWithAnimation(
                        CoupleProfilePage(
                          boyImage: widget.boyImage,
                          girlImage: widget.girlImage,
                        ),
                      );
                    },
                    child: _buildCouplePortrait(width, cp, isLoading),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    width: width * .78,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.82),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouplePortrait(
      double width,
      CpRequestModel? cp,
      bool isLoading,
      ) {
    final boxWidth = width.clamp(300.0, 400.0).toDouble();
    final imageSize = (boxWidth * .34).clamp(104.0, 126.0).toDouble();

    final leftImage = cp?.me.profileImage ?? widget.boyImage;
    final rightImage = cp?.partner.profileImage ?? widget.girlImage;
    final useNetwork = cp != null;

    return SizedBox(
      height: imageSize + 12,
      width: boxWidth,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: boxWidth * .15,
            child: _profileCircle(
              image: leftImage,
              size: imageSize,
              isBoy: true,
              isLoading: isLoading,
              useNetwork: useNetwork,
            ),
          ),
          Positioned(
            right: boxWidth * .15,
            child: _profileCircle(
              image: rightImage,
              size: imageSize,
              isBoy: false,
              isLoading: isLoading,
              useNetwork: useNetwork,
            ),
          ),
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.25),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffff70ad).withOpacity(.95),
                  blurRadius: 26,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                height: 45,
                width: 45,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xffff9ac5),
                      Color(0xffff4f92),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 27,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileCircle({
    required String? image,
    required double size,
    required bool isBoy,
    required bool isLoading,
    required bool useNetwork,
  }) {
    if (isLoading) {
      return Container(
        height: size,
        width: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Colors.white,
              Color(0xffffc8df),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(.35),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: CpShimmerBox.circle(size: size - 6),
      );
    }

    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [
            Colors.white,
            Color(0xffffc8df),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(.35),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: image == null || image.isEmpty
            ? Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isBoy
                  ? const [Color(0xff1f1f3e), Color(0xff7252a5)]
                  : const [Color(0xffffadc9), Color(0xff8c3c74)],
            ),
          ),
          child: Icon(
            isBoy ? Icons.person_rounded : Icons.person_2_rounded,
            color: Colors.white,
            size: size * .55,
          ),
        )
            : useNetwork
            ? CpImage(
          imageUrl: image,
          size: size,
          iconSize: size * .52,
        )
            : Image.asset(
          image,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildBodyPanel(
      double width,
      double height,
      double headerHeight,
      CpRequestModel? cp,
      bool isLoading,
      ) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: height - headerHeight + 40,
      ),
      decoration: BoxDecoration(
        color: const Color(0xfffff8fb),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 34),
        child: Column(
          children: [
            const SizedBox(height: 18),
            _buildMenuGrid(width),
            // const SizedBox(height: 18),
            _cpLevelProgressCard(),
            const SizedBox(height: 16),
            _loveCounterCard(cp, isLoading),
            const SizedBox(height: 16),
            _quoteCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuGrid(double width) {
    final items = [
      _MenuItem(
        ('Couple Chat').appTr,
        Icons.chat_bubble_rounded,
        const Color(0xffff5b91),
        const Color(0xffffeef5),
        page: const CoupleChatRouter(),
      ),
      _MenuItem(
        ('Love Counter').appTr,
        Icons.favorite_rounded,
        const Color(0xff8f58ff),
        const Color(0xfff4efff),
        page: const LoveCounterPage(),
      ),
      _MenuItem(
        ('Anniversary').appTr,
        Icons.event_available_rounded,
        const Color(0xffffab2e),
        const Color(0xfffff5e5),
        page: const AnniversaryPage(),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: .82,
      ),
      itemBuilder: (context, index) {
        return _quickCard(items[index]);
      },
    );
  }

  Widget _quickCard(_MenuItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openPageWithAnimation(item.page),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: item.iconColor.withOpacity(.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Container(
                height: 39,
                width: 39,
                decoration: BoxDecoration(
                  color: item.bgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: item.iconColor,
                  size: 23,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            item.title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff222230),
              fontSize: 11.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  Widget _cpLevelProgressCard() {
    final current = cpController.cpCurrentLevel.value;
    final isLoading = cpController.isLevelLoading.value && current == null;
    final coins = current?.coins ?? 0;
    final currentLevelNo = current?.currentLevelNo ?? 0;
    final nextLevel = current?.nextLevel;
    final targetCoins = current?.targetCoins ?? nextLevel?.requiredCoins ?? 0;
    final needMore = current?.needMoreCoins ?? targetCoins;
    final progress = current?.progressValue ?? 0.0;
    final isMax = current?.isMaxLevel ?? false;

    final levelTitle = isMax
        ? 'Max CP Level'
        : currentLevelNo <= 0
        ? 'Love Level 0'
        : 'Love Level $currentLevelNo';

    final rightText = isMax
        ? '${cpCompactNumber(coins)} ❤'
        : '${cpCompactNumber(coins)} / ${cpCompactNumber(targetCoins)}';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openPageWithAnimation(const CpLevelPage()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff2b174f),
              Color(0xff5d327b),
              Color(0xff40205f),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xff40205f).withOpacity(.20),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              top: -24,
              child: Icon(
                Icons.favorite,
                size: 96,
                color: Colors.white.withOpacity(.055),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                     Text(
                      ('Our Progress').appTr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.12),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.white.withOpacity(.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Color(0xffff72ab),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          isLoading
                              ? const CpShimmerBox(
                            width: 42,
                            height: 10,
                            radius: 8,
                          )
                              : Text(
                            rightText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.22),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: isLoading ? .38 : progress,
                        child: Container(
                          height: 8,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xffff6ca8),
                                Color(0xffffc1db),
                                Color(0xff9b5bff),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: isLoading
                          ? const CpShimmerBox(
                        width: 120,
                        height: 13,
                        radius: 8,
                      )
                          : Text(
                        levelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.92),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isLoading)
                      Text(
                        isMax ? ('Completed').appTr: ('Need ${cpCompactNumber(needMore)}').appTr,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.72),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(.72),
                      size: 13,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _loveCounterCard(CpRequestModel? cp, bool isLoading) {
    final daysText = cp == null ? '0 Days' : '${cp.daysTogether} Days';
    final dateText = cp == null ? ('Accepted CP will show here').appTr : ('Since ${cp.sinceFullDate}').appTr;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openPageWithAnimation(const LoveCounterPage()),
      child: Container(
        height: 138,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xffffffff),
              Color(0xfffff0f7),
              Color(0xffffddeb),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffff7daf).withOpacity(.15),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CherryPainter(),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Color(0xffff4d86),
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ('Love Counter').appTr,
                              style: TextStyle(
                                color: const Color(0xff2d2832).withOpacity(.95),
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          ('Together For').appTr,
                          style: TextStyle(
                            color: Colors.black.withOpacity(.48),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        isLoading
                            ? const CpShimmerBox(
                          width: 115,
                          height: 26,
                          radius: 10,
                        )
                            : Text(
                          daysText,
                          style: const TextStyle(
                            color: Color(0xff2a2630),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        isLoading
                            ? const CpShimmerBox(
                          width: 140,
                          height: 12,
                          radius: 10,
                        )
                            : Text(
                          dateText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black.withOpacity(.46),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 118,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.favorite,
                        color: Colors.pink.shade200.withOpacity(.8),
                        size: 25,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _smallPerson(const Color(0xff2e355f)),
                          const SizedBox(width: 5),
                          _smallPerson(const Color(0xffff7aaa)),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        height: 5,
                        width: 82,
                        decoration: BoxDecoration(
                          color: const Color(0xff77c86d).withOpacity(.35),
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallPerson(Color color) {
    return Column(
      children: [
        Container(
          height: 15,
          width: 15,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        Container(
          height: 26,
          width: 20,
          decoration: BoxDecoration(
            color: color.withOpacity(.9),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
              bottom: Radius.circular(5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned(
                  top: -8,
                  left: 0,
                  child: Text(
                    '“',
                    style: TextStyle(
                      color: Colors.pink.shade100,
                      fontSize: 48,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                 Padding(
                  padding: EdgeInsets.only(top: 28),
                  child: Text(
                    ("In your arms, I've found my home. In your heart, I've found my love.").appTr,
                    style: TextStyle(
                      color: Color(0xff32313c),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 76,
            height: 82,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  right: 9,
                  top: 5,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.pink.shade200,
                    size: 40,
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 22,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.pink.shade300,
                    size: 38,
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 8,
                  child: Container(
                    height: 30,
                    width: 2,
                    color: Colors.pink.shade100,
                  ),
                ),
                Positioned(
                  left: 24,
                  bottom: 6,
                  child: Container(
                    height: 27,
                    width: 2,
                    color: Colors.pink.shade100,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Widget page;

  _MenuItem(
      this.title,
      this.icon,
      this.iconColor,
      this.bgColor, {
        required this.page,
      });
}

class _HeartParticle {
  final double dx;
  final double size;
  final double speed;
  final double phase;
  final double opacity;
  final Color color;

  _HeartParticle({
    required this.dx,
    required this.size,
    required this.speed,
    required this.phase,
    required this.opacity,
    required this.color,
  });
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(11);
    final paint = Paint();

    for (int i = 0; i < 90; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.7 + .4;

      paint.color = Colors.white.withOpacity(.10 + random.nextDouble() * .35);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xffff70b6).withOpacity(.38),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .52, size.height * .43),
          radius: size.width * .52,
        ),
      );

    canvas.drawCircle(
      Offset(size.width * .52, size.height * .43),
      size.width * .52,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CherryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final branchPaint = Paint()
      ..color = const Color(0xffff9fc5).withOpacity(.55)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * .58, size.height * .24)
      ..quadraticBezierTo(
        size.width * .78,
        size.height * .06,
        size.width * .98,
        size.height * .14,
      );

    canvas.drawPath(path, branchPaint);

    final random = math.Random(4);
    final flowerPaint = Paint();

    for (int i = 0; i < 24; i++) {
      final x = size.width * (.58 + random.nextDouble() * .38);
      final y = size.height * (.05 + random.nextDouble() * .36);
      flowerPaint.color = const Color(0xffff7eb3).withOpacity(.25);
      canvas.drawCircle(Offset(x, y), 3 + random.nextDouble() * 3, flowerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}