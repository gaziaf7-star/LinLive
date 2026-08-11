import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../constants/color_constants.dart';

import '../../controllers/home_controller.dart';
import '../all_live_live_view.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';

class CountryLiveListView extends StatefulWidget {
  const CountryLiveListView({super.key});

  @override
  State<CountryLiveListView> createState() => _CountryLiveListViewState();
}

class _CountryLiveListViewState extends State<CountryLiveListView>
    with AutomaticKeepAliveClientMixin<CountryLiveListView> {
  late final HomeController controller;
  final ScrollController _scrollController = ScrollController();
  bool _resolvingCountries = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeController>();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareCountryTab();
    });
  }

  Future<void> _prepareCountryTab() async {
    if (_resolvingCountries) return;
    _resolvingCountries = true;

    try {
      controller.syncSelectedLiveCountryFromProfile();

      // Some livestream payloads do not contain country directly.
      // Load user resolver only when Country tab is actually used.
      if (controller.allUserData.isEmpty) {
        await controller.showAllUserData();
      }

      controller.sortLiveStreamList();

      await controller.ensureSelectedCountryLivestreams(
        minimumResults: 8,
        maxAdditionalPages: 8,
      );
    } finally {
      _resolvingCountries = false;
      if (mounted) setState(() {});
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 360) return;

    final currentCount = controller.selectedCountryLiveStreams.length;
    controller.ensureSelectedCountryLivestreams(
      minimumResults: currentCount + 6,
      maxAdditionalPages: 3,
    );
  }

  int _gridCount(double width) {
    if (width >= 900) return 4;
    if (width >= 620) return 3;
    return 2;
  }

  double _gridRatio(double width) {
    if (width >= 900) return .98;
    if (width >= 620) return 1.0;
    return 1.02;
  }

  Widget _loadingGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = _gridCount(constraints.maxWidth);

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
          itemCount: count * 4,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: _gridRatio(constraints.maxWidth),
          ),
          itemBuilder: (_, __) {
            return Shimmer.fromColors(
              baseColor: Colors.white.withOpacity(.12),
              highlightColor: Colors.white.withOpacity(.28),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyState() {
    return Obx(() {
      final String name = controller.selectedLiveCountryName.value;
      final String flag = controller.selectedLiveCountryFlag.value;
      final bool canLoadMore = controller.liveHasMore.value;

      return RefreshIndicator(
        color: kAppColor,
        onRefresh: controller.refreshSelectedCountryLivestreams,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * .10),
            Center(
              child: Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.10),
                  border: Border.all(
                    color: Colors.white.withOpacity(.12),
                  ),
                ),
                child: Text(
                  flag,
                  style: const TextStyle(fontSize: 31),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name == 'Global'
                  ? ('No Stream Available').appTr
                  : '${('No live room found for').appTr} $name',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              canLoadMore
                  ? ('More live pages are available. Tap below to search this country.').appTr
                  : ('New live rooms will appear here automatically.').appTr,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(.62),
                fontSize: 11.2,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (canLoadMore) ...[
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: kAppColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      controller.ensureSelectedCountryLivestreams(
                        minimumResults: 8,
                        maxAdditionalPages: 12,
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(
                      ('Load country live').appTr,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF3B072F),
            Color(0xFF3B072F),
          ],
        ),
      ),
      child: Obx(() {
        final users = controller.selectedCountryLiveStreams;

        if ((controller.isLoading.value || _resolvingCountries) &&
            users.isEmpty) {
          return _loadingGrid();
        }

        if (users.isEmpty) {
          return _emptyState();
        }

        return RefreshIndicator(
          color: kAppColor,
          onRefresh: controller.refreshSelectedCountryLivestreams,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final int crossAxisCount = _gridCount(constraints.maxWidth);
              final bool loadingMore =
                  controller.isLoadingMoreLive.value || _resolvingCountries;

              return GridView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                itemCount:
                users.length + (loadingMore ? crossAxisCount : 0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: _gridRatio(constraints.maxWidth),
                ),
                itemBuilder: (context, index) {
                  if (index >= users.length) {
                    return Shimmer.fromColors(
                      baseColor: Colors.white.withOpacity(.12),
                      highlightColor: Colors.white.withOpacity(.28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    );
                  }

                  final item = users[index];
                  final dynamic id = item is Map
                      ? (item['id'] ??
                      item['livestream_id'] ??
                      item['stream_id'])
                      : index;

                  return RepaintBoundary(
                    child: UserProfileCard(
                      key: ValueKey(
                        'country_live_${controller.selectedLiveCountryName.value}_${id ?? index}',
                      ),
                      data: item,
                      index: index,
                      compact: false,
                    ),
                  );
                },
              );
            },
          ),
        );
      }),
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }
}
