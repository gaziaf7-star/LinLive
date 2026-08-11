import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../registersteps/controllers/registersteps_controller.dart';

import 'google_profile_setup_view.dart';

class GoogleCountrySelectView extends StatefulWidget {
  const GoogleCountrySelectView({super.key});

  @override
  State<GoogleCountrySelectView> createState() =>
      _GoogleCountrySelectViewState();
}

class _GoogleCountrySelectViewState extends State<GoogleCountrySelectView> {
  late final RegisterstepsController controller;
  late final List<Country> countries;

  @override
  void initState() {
    super.initState();
    controller = Get.find<RegisterstepsController>();
    countries = List<Country>.from(CountryService().getAll())
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  String _flagFor(String code) {
    final String clean = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(clean)) return '🌐';
    return String.fromCharCodes(
      clean.codeUnits.map((unit) => unit + 127397),
    );
  }

  Future<void> _goBack() async {
    await controller.cancelGoogleOnboarding();
  }

  void _next() {
    if (controller.googleSelectedCountryName.value.trim().isEmpty) return;

    Get.to(
          () => const GoogleProfileSetupView(),
      transition: Transition.rightToLeftWithFade,
      duration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _goBack,
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 27,
                        color: Color(0xff292929),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 64),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select country',
                    style: GoogleFonts.poppins(
                      fontSize: 31,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xff2D2D2D),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const _NoGlowScrollBehavior(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(36, 0, 31, 130),
                    physics: const BouncingScrollPhysics(),
                    itemCount: countries.length,
                    itemBuilder: (context, index) {
                      final Country country = countries[index];

                      return Obx(() {
                        final bool selected = controller
                            .googleSelectedCountryCode.value ==
                            country.countryCode.toUpperCase();

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            controller.selectGoogleCountry(
                              name: country.name,
                              countryCode: country.countryCode,
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            constraints: const BoxConstraints(minHeight: 74),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 1,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? kAppColor.withOpacity(.055)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    country.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selected
                                          ? kAppColor
                                          : const Color(0xff585A62),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 56,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xffFAFAFA),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: selected
                                          ? kPostIconColor.withOpacity(.55)
                                          : const Color(0xffEEEEEE),
                                      width: selected ? 1.2 : .8,
                                    ),
                                  ),
                                  child: Text(
                                    _flagFor(country.countryCode),
                                    style: const TextStyle(fontSize: 29),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 10, 28, 20),
            child: Obx(() {
              final bool enabled =
                  controller.googleSelectedCountryName.value.trim().isNotEmpty;

              return AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: enabled ? 1 : .58,
                child: SizedBox(
                  height: 58,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: enabled
                          ? const LinearGradient(
                        colors: [kAppColor, kPostIconColor],
                      )
                          : const LinearGradient(
                        colors: [Color(0xffC9C7C4), Color(0xffD8D5D1)],
                      ),
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: enabled
                          ? [
                        BoxShadow(
                          color: kPostIconColor.withOpacity(.20),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ]
                          : const [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(34),
                        onTap: enabled ? _next : null,
                        child: Center(
                          child: Text(
                            'Next',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends MaterialScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return child;
  }
}
