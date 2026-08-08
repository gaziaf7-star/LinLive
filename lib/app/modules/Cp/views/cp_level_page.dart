import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/cp_data_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class CpLevelPage extends StatefulWidget {
  const CpLevelPage({super.key});

  @override
  State<CpLevelPage> createState() => _CpLevelPageState();
}

class _CpLevelPageState extends State<CpLevelPage> {
  final CpDataController cpController = Get.isRegistered<CpDataController>()
      ? Get.find<CpDataController>()
      : Get.put(CpDataController());

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      cpController.fetchCpLevelData(showLoader: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = cpController.cpCurrentLevel.value;
      final levels = cpController.cpLevels;
      final isLoading = cpController.isLevelLoading.value &&
          current == null &&
          levels.isEmpty;

      return Scaffold(
        backgroundColor: const Color(0xfffff7fb),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: RefreshIndicator(
              onRefresh: () => cpController.fetchCpLevelData(),
              child: CustomScrollView(
                // physics: const AlwaysScrollableScrollPhysics(
                //   parent: BouncingScrollPhysics(),
                // ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(context, current, isLoading),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: _buildCurrentInfoCard(current, isLoading),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                      child: Row(
                        children: [
                           Text(
                            ('CP Level Rewards').appTr,
                            style: TextStyle(
                              color: Color(0xff211d2b),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            ('${levels.length} Levels').appTr,
                            style: TextStyle(
                              color: const Color(0xff211d2b).withOpacity(.52),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isLoading)
                    SliverList.builder(
                      itemCount: 8,
                      itemBuilder: (context, index) {
                        return const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: CpShimmerBox(
                            width: double.infinity,
                            height: 76,
                            radius: 20,
                          ),
                        );
                      },
                    )
                  else if (levels.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _emptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      sliver: SliverList.builder(
                        itemCount: levels.length,
                        itemBuilder: (context, index) {
                          return _buildLevelTile(
                            levels[index],
                            current,
                            index,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildHeader(
      BuildContext context,
      CpCurrentLevelModel? current,
      bool isLoading,
      ) {
    final coins = current?.coins ?? 0;
    final currentLevelNo = current?.currentLevelNo ?? 0;
    final title = current?.isMaxLevel == true
        ? 'Max Level'
        : currentLevelNo <= 0
        ? 'Love Level 0'
        : 'Love Level $currentLevelNo';

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 8,
        16,
        22,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xff190a35),
            Color(0xff4c1e70),
            Color(0xff8c2c6f),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
               Expanded(
                child: Center(
                  child: Text(
                    ('CP Level').appTr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => cpController.fetchCpLevelData(),
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 78,
            width: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xffffc1dd),
                  Color(0xffff5b9a),
                  Color(0xff9b5bff),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffff5b9a).withOpacity(.42),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const CpShimmerBox.circle(size: 52)
                  : Text(
                currentLevelNo <= 0 ? '0' : currentLevelNo.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          isLoading
              ? const CpShimmerBox(width: 140, height: 20, radius: 12)
              : Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ('${cpCompactNumber(coins)} CP Coins').appTr,
            style: TextStyle(
              color: Colors.white.withOpacity(.78),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentInfoCard(
      CpCurrentLevelModel? current,
      bool isLoading,
      ) {
    final coins = current?.coins ?? 0;
    final target = current?.targetCoins ?? 0;
    final progress = current?.progressValue ?? 0.0;
    final needMore = current?.needMoreCoins ?? target;
    final isMax = current?.isMaxLevel ?? false;
    final nextTitle = current?.nextLevelTitle ?? 'CP Level 1';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(.09),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xffffedf6),
                      Color(0xffffcae0),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xffff4f8f),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      ('Current Progress').appTr,
                      style: TextStyle(
                        color: Color(0xff211d2b),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isMax ? ('You reached max CP level').appTr: ('Next: $nextTitle').appTr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xff211d2b).withOpacity(.52),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const CpShimmerBox(width: double.infinity, height: 10, radius: 20)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    minHeight: 10,
                    value: value,
                    backgroundColor: const Color(0xffffe2f0),
                    color: const Color(0xffff5b9a),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _progressStat(
                title: ('Coins').appTr,
                value: cpCompactNumber(coins),
              ),
              Container(
                width: 1,
                height: 34,
                color: const Color(0xff211d2b).withOpacity(.08),
              ),
              _progressStat(
                title: isMax ? ('Status').appTr: ('Need More').appTr,
                value: isMax ? 'Done': cpCompactNumber(needMore),
              ),
              Container(
                width: 1,
                height: 34,
                color: const Color(0xff211d2b).withOpacity(.08),
              ),
              _progressStat(
                title: ('Target').appTr,
                value: isMax ? 'Max' : cpCompactNumber(target),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressStat({
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xff211d2b),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: const Color(0xff211d2b).withOpacity(.50),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelTile(
      CpLevelModel level,
      CpCurrentLevelModel? current,
      int index,
      ) {
    final currentLevelNo = current?.currentLevelNo ?? 0;
    final currentCoins = current?.coins ?? 0;
    final isCompleted = currentLevelNo >= level.levelNo ||
        currentCoins >= level.requiredCoins ||
        current?.isMaxLevel == true;
    final isNext = !isCompleted && current?.nextLevel?.id == level.id;

    return AnimatedContainer(
      duration: Duration(milliseconds: 260 + index * 8),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        border: Border.all(
          color: isNext
              ? const Color(0xffff5b9a).withOpacity(.60)
              : isCompleted
              ? const Color(0xff45c486).withOpacity(.30)
              : const Color(0xff211d2b).withOpacity(.06),
          width: isNext ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isNext ? Colors.pink : Colors.black).withOpacity(.07),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isCompleted
                    ? const [Color(0xff45c486), Color(0xff90e6b8)]
                    : isNext
                    ? const [Color(0xffff5b9a), Color(0xff9b5bff)]
                    : const [Color(0xffffedf6), Color(0xffffd8ea)],
              ),
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 28,
              )
                  : Text(
                level.levelNo.toString(),
                style: TextStyle(
                  color: isNext
                      ? Colors.white
                      : const Color(0xffff5b9a),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        level.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xff211d2b),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isNext)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffffedf6),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child:  Text(
                          ('NEXT').appTr,
                          style: TextStyle(
                            color: Color(0xffff4f8f),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xffff5b9a),
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      ('${cpCompactNumber(level.requiredCoins)} Coins required').appTr,
                      style: TextStyle(
                        color: const Color(0xff211d2b).withOpacity(.55),
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            isCompleted
                ? Icons.lock_open_rounded
                : isNext
                ? Icons.flag_rounded
                : Icons.lock_rounded,
            color: isCompleted
                ? const Color(0xff45c486)
                : isNext
                ? const Color(0xffff4f8f)
                : const Color(0xff211d2b).withOpacity(.22),
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xffffe4f1),
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                color: Color(0xffff4f8f),
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
             Text(
              ('No CP Level Found').appTr,
              style: TextStyle(
                color: Color(0xff211d2b),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              cpController.levelErrorMessage.value.isEmpty
                  ? ('Please refresh and try again.').appTr: cpController.levelErrorMessage.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xff211d2b).withOpacity(.55),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () => cpController.fetchCpLevelData(),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xffff7cab),
                      Color(0xffff4f8f),
                    ],
                  ),
                ),
                child:  Center(
                  child: Text(
                    ('Refresh').appTr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
