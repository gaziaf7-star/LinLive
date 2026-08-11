import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
import '../../controllers/home_controller.dart';

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

  HomeController get _homeController => Get.find<HomeController>();

  String _flagFromCode(String code) {
    final clean = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(clean)) return '🌍';
    return String.fromCharCodes(
      clean.codeUnits.map((unit) => unit + 127397),
    );
  }

  String _flagForCountryName(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'global') return '🌐';

    for (final country in CountryService().getAll()) {
      if (country.name.trim().toLowerCase() == normalized) {
        return _flagFromCode(country.countryCode);
      }
    }

    return _homeController.selectedLiveCountryFlag.value;
  }

  List<String> _tabs(String countryName) => [
    'All'.appTr,
    'Video'.appTr,
    'Audio'.appTr,
    'PK'.appTr,
    countryName,
  ];

  Widget _buildTab({
    required BuildContext context,
    required String text,
    required int index,
    required TabController controller,
    String? countryFlag,
  }) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double tabHeight = (screenWidth * 0.074).clamp(27.0, 31.0);
    final double horizontalPadding =
    (screenWidth * 0.026).clamp(8.0, 12.0);
    final double fontSize = (screenWidth * 0.031).clamp(11.2, 13.2);
    final double iconSize = (screenWidth * 0.038).clamp(14.0, 17.0);

    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) {
        final bool isSelected = controller.index == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 210),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(
            minHeight: tabHeight,
            maxWidth: index == 4
                ? (screenWidth * .30).clamp(92.0, 122.0)
                : double.infinity,
          ),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
              colors: [_selectedColor1, _selectedColor2],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            )
                : null,
            color: isSelected ? null : Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(tabHeight / 2),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.15)
                  : Colors.white.withOpacity(0.08),
              width: .8,
            ),
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
                      : Colors.white.withOpacity(.72),
                ),
                const SizedBox(width: 3),
              ],
              if (index == 4 && countryFlag != null) ...[
                Text(
                  countryFlag,
                  style: TextStyle(fontSize: iconSize - 1),
                ),
                const SizedBox(width: 4),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: index == 4
                      ? (screenWidth * .20).clamp(58.0, 82.0)
                      : (screenWidth * .22).clamp(62.0, 88.0),
                ),
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lato(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(.78),
                    fontSize: fontSize,
                    fontWeight:
                    isSelected ? FontWeight.w800 : FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCountryFilter(
      BuildContext context,
      TabController tabController,
      ) async {
    await _homeController.bootstrapSelectedLiveCountryFromProfile();
    if (!mounted) return;

    final Country? picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.48),
      builder: (_) => _HomeCountryFilterSheet(
        selectedCountryName: _homeController.selectedLiveCountryName.value,
      ),
    );

    if (picked == null || !mounted) return;

    _homeController.changeLiveCountry(
      name: picked.name,
      flagEmoji: _flagFromCode(picked.countryCode),
    );

    tabController.animateTo(
      4,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );

    // Country tab already mounted thakleo new selection-er matching live
    // automatically progressively load hobe.
    await _homeController.ensureSelectedCountryLivestreams(
      minimumResults: 1,
      maxAdditionalPages: 8,
    );
  }

  Widget _filterButton(
      BuildContext context,
      TabController controller,
      double rowHeight,
      ) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double size = (screenWidth * .078).clamp(29.0, 33.0);

    return Padding(
      padding: EdgeInsets.only(
        right: (screenWidth * .026).clamp(8.0, 12.0),
        left: 3,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: () => _openCountryFilter(context, controller),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.12),
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(
                color: Colors.white.withOpacity(.12),
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: size * .56,
              color: Colors.white.withOpacity(.90),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TabController controller = DefaultTabController.of(context);
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double outerLeft = (screenWidth * 0.030).clamp(8.0, 13.0);
    final double tabGap = (screenWidth * 0.014).clamp(4.0, 6.0);
    final double rowHeight = (screenWidth * 0.092).clamp(34.0, 39.0);

    return Obx(() {
      final String selectedCountry =
      _homeController.selectedLiveCountryName.value.trim().isEmpty
          ? 'Global'
          : _homeController.selectedLiveCountryName.value.trim();
      final String selectedFlag = _flagForCountryName(selectedCountry);
      final tabs = _tabs(selectedCountry);

      return SizedBox(
        width: double.infinity,
        height: rowHeight,
        child: Row(
          children: [
            Expanded(
              child: TabBar(
                controller: controller,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicator: const BoxDecoration(color: Colors.transparent),
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor:
                MaterialStateProperty.all(Colors.transparent),
                indicatorPadding: EdgeInsets.zero,
                padding: EdgeInsets.only(
                  left: outerLeft,
                  top: 2,
                  bottom: 2,
                ),
                labelPadding: EdgeInsets.only(right: tabGap),
                tabs: List.generate(
                  tabs.length,
                      (index) => Tab(
                    height: rowHeight - 4,
                    child: _buildTab(
                      context: context,
                      text: tabs[index],
                      index: index,
                      controller: controller,
                      countryFlag: index == 4 ? selectedFlag : null,
                    ),
                  ),
                ),
              ),
            ),
            _filterButton(context, controller, rowHeight),
          ],
        ),
      );
    });
  }
}

class _HomeCountryFilterSheet extends StatefulWidget {
  const _HomeCountryFilterSheet({
    required this.selectedCountryName,
  });

  final String selectedCountryName;

  @override
  State<_HomeCountryFilterSheet> createState() =>
      _HomeCountryFilterSheetState();
}

class _HomeCountryFilterSheetState extends State<_HomeCountryFilterSheet> {
  late final List<Country> _countries;
  late String _selectedRegion;

  static const List<String> _regions = <String>[
    'Middle East',
    'Asia',
    'America',
    'Europe',
    'Africa',
    'Oceania',
    'All',
  ];

  static const Set<String> _middleEast = <String>{
    'AE', 'BH', 'EG', 'IQ', 'IR', 'IL', 'JO', 'KW', 'LB', 'OM',
    'PS', 'QA', 'SA', 'SY', 'TR', 'YE',
  };

  static const Set<String> _asia = <String>{
    'AF', 'AM', 'AZ', 'BD', 'BT', 'BN', 'KH', 'CN', 'GE', 'HK',
    'IN', 'ID', 'JP', 'KZ', 'KG', 'LA', 'MO', 'MY', 'MV', 'MN',
    'MM', 'NP', 'KP', 'PK', 'PH', 'SG', 'KR', 'LK', 'TW', 'TJ',
    'TH', 'TL', 'TM', 'UZ', 'VN',
  };

  static const Set<String> _america = <String>{
    'AG', 'AR', 'BS', 'BB', 'BZ', 'BO', 'BR', 'CA', 'CL', 'CO',
    'CR', 'CU', 'DM', 'DO', 'EC', 'SV', 'GD', 'GT', 'GY', 'HT',
    'HN', 'JM', 'MX', 'NI', 'PA', 'PY', 'PE', 'KN', 'LC', 'VC',
    'SR', 'TT', 'US', 'UY', 'VE', 'PR',
  };

  static const Set<String> _europe = <String>{
    'AL', 'AD', 'AT', 'BY', 'BE', 'BA', 'BG', 'HR', 'CY', 'CZ',
    'DK', 'EE', 'FI', 'FR', 'DE', 'GR', 'HU', 'IS', 'IE', 'IT',
    'LV', 'LI', 'LT', 'LU', 'MT', 'MD', 'MC', 'ME', 'NL', 'MK',
    'NO', 'PL', 'PT', 'RO', 'RU', 'SM', 'RS', 'SK', 'SI', 'ES',
    'SE', 'CH', 'UA', 'GB', 'VA',
  };

  static const Set<String> _africa = <String>{
    'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD',
    'KM', 'CG', 'CD', 'CI', 'DJ', 'GQ', 'ER', 'SZ', 'ET', 'GA',
    'GM', 'GH', 'GN', 'GW', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW',
    'ML', 'MR', 'MU', 'MA', 'MZ', 'NA', 'NE', 'NG', 'RW', 'ST',
    'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD', 'TZ', 'TG', 'TN',
    'UG', 'ZM', 'ZW',
  };

  static const Set<String> _oceania = <String>{
    'AU', 'FJ', 'KI', 'MH', 'FM', 'NR', 'NZ', 'PW', 'PG', 'WS',
    'SB', 'TO', 'TV', 'VU',
  };

  @override
  void initState() {
    super.initState();
    _countries = List<Country>.from(CountryService().getAll())
      ..sort((a, b) => a.name.compareTo(b.name));
    _selectedRegion = _regionForSelectedCountry();
  }

  String _regionForCode(String code) {
    final c = code.toUpperCase();
    if (_middleEast.contains(c)) return 'Middle East';
    if (_asia.contains(c)) return 'Asia';
    if (_america.contains(c)) return 'America';
    if (_europe.contains(c)) return 'Europe';
    if (_africa.contains(c)) return 'Africa';
    if (_oceania.contains(c)) return 'Oceania';
    return 'All';
  }

  String _regionForSelectedCountry() {
    final selected = widget.selectedCountryName.trim().toLowerCase();
    for (final country in _countries) {
      if (country.name.trim().toLowerCase() == selected) {
        return _regionForCode(country.countryCode);
      }
    }
    return 'All';
  }

  List<Country> get _visibleCountries {
    if (_selectedRegion == 'All') return _countries;

    return _countries.where((country) {
      return _regionForCode(country.countryCode) == _selectedRegion;
    }).toList(growable: false);
  }

  String _flagFor(String code) {
    final clean = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(clean)) return '🌍';
    return String.fromCharCodes(
      clean.codeUnits.map((unit) => unit + 127397),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final bool compact = screen.width < 350;
    final int columns = screen.width >= 720
        ? 4
        : compact
        ? 2
        : 3;
    final double height = (screen.height * .60).clamp(360.0, 520.0);

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xffFCFCFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 7),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xffD8D9DE),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 20,
                9,
                compact ? 8 : 12,
                3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select country'.appTr,
                      style: GoogleFonts.poppins(
                        fontSize: compact ? 19 : 21,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff25262A),
                        letterSpacing: -.25,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 30,
                      color: Color(0xff25262A),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 39,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 14 : 20,
                ),
                itemCount: _regions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final region = _regions[index];
                  final selected = region == _selectedRegion;
        
                  return InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      setState(() => _selectedRegion = region);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xffF4F0FF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            region.appTr,
                            style: GoogleFonts.poppins(
                              fontSize: compact ? 11.3 : 12.2,
                              fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? const Color(0xff25262A)
                                  : const Color(0xff8C8E95),
                            ),
                          ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: selected ? 26 : 0,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? const LinearGradient(
                                colors: [kAppColor1, kAppColor2],
                              )
                                  : null,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: GridView.builder(
                  key: ValueKey(_selectedRegion),
                  padding: EdgeInsets.fromLTRB(
                    compact ? 14 : 20,
                    5,
                    compact ? 14 : 20,
                    22,
                  ),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: compact ? 8 : 10,
                    mainAxisSpacing: compact ? 9 : 10,
                    childAspectRatio: compact ? 2.55 : 2.85,
                  ),
                  itemCount: _visibleCountries.length,
                  itemBuilder: (context, index) {
                    final country = _visibleCountries[index];
                    final bool selected =
                        country.name.trim().toLowerCase() ==
                            widget.selectedCountryName.trim().toLowerCase();
        
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, country),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          decoration: BoxDecoration(
                            color: selected
                                ? kAppColor1.withOpacity(.075)
                                : const Color(0xffF2F2F3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? kAppColor1.withOpacity(.34)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  country.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: compact ? 10.8 : 11.5,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? kAppColor1
                                        : const Color(0xff66686F),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _flagFor(country.countryCode),
                                style: TextStyle(
                                  fontSize: compact ? 16 : 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
