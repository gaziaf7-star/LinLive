import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'beauty_effect_page.dart';
import 'filter_effect_page.dart';
import 'makeup_effect_page.dart';
import 'presets_effect_page.dart';
import 'video_effect_models.dart';
import 'video_effects_controller.dart';

Future<void> showProfessionalVideoEffectsSheet(
    BuildContext context, {
      VideoEffectsSection initialSection = VideoEffectsSection.presets,
      VideoEffectsController? controller,
    }) async {
  final VideoEffectsController effectiveController =
      controller ?? VideoEffectsController();
  final bool ownsController = controller == null;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfessionalVideoEffectsSheet(
        controller: effectiveController,
        initialSection: initialSection,
      ),
    );
  } finally {
    if (ownsController) effectiveController.dispose();
  }
}

class ProfessionalVideoEffectsSheet extends StatefulWidget {
  const ProfessionalVideoEffectsSheet({
    super.key,
    required this.controller,
    required this.initialSection,
  });

  final VideoEffectsController controller;
  final VideoEffectsSection initialSection;

  @override
  State<ProfessionalVideoEffectsSheet> createState() =>
      _ProfessionalVideoEffectsSheetState();
}

class _ProfessionalVideoEffectsSheetState
    extends State<ProfessionalVideoEffectsSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      initialIndex: widget.initialSection.index,
      vsync: this,
    );
    _tabController.addListener(_handleTab);
  }

  void _handleTab() {
    if (_tabController.indexIsChanging) return;
    widget.controller.setSection(
      VideoEffectsSection.values[_tabController.index],
    );
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTab);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height * .43,
        decoration: const BoxDecoration(
          color: Color(0xFF1D1E22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 9),
              Container(
                height: 4,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              SizedBox(
                height: 62,
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.white10,
                  indicatorColor: const Color(0xFF71E8D6),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: const [
                    Tab(text: '✦ Presets'),
                    Tab(text: 'Beauty'),
                    Tab(text: 'Make up'),
                    Tab(text: 'Filter'),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    TabBarView(
                      controller: _tabController,
                      children: [
                        PresetsEffectPage(controller: widget.controller),
                        BeautyEffectPage(controller: widget.controller),
                        MakeupEffectPage(controller: widget.controller),
                        FilterEffectPage(controller: widget.controller),
                      ],
                    ),
                    Positioned(
                      top: 4,
                      right: 10,
                      child: AnimatedBuilder(
                        animation: widget.controller,
                        builder: (context, _) {
                          if (!widget.controller.applying) {
                            return const SizedBox.shrink();
                          }
                          return const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Color(0xFF71E8D6),
                            ),
                          );
                        },
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
  }
}
