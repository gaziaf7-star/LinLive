import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'effect_widgets.dart';
import 'video_effects_controller.dart';

class BeautyEffectPage extends StatefulWidget {
  const BeautyEffectPage({
    super.key,
    required this.controller,
  });

  final VideoEffectsController controller;

  @override
  State<BeautyEffectPage> createState() => _BeautyEffectPageState();
}

class _BeautyEffectPageState extends State<BeautyEffectPage> {
  int category = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        return Column(
          children: [
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: List.generate(
                  const ['Touch Up', 'Skin', 'Tone', 'Detail'].length,
                      (index) => SectionChip(
                    label: const ['Touch Up', 'Skin', 'Tone', 'Detail'][index],
                    selected: category == index,
                    onTap: () => setState(() => category = index),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: c.resetAll,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reset all'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white54,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Text(
                              'Low light',
                              style: GoogleFonts.poppins(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            Switch.adaptive(
                              value: c.lowLight,
                              activeColor: const Color(0xFF71E8D6),
                              onChanged: (v) => c.setEnhancement(
                                lowLightEnabled: v,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    EffectSliderRow(
                      label: 'Brighten',
                      icon: Icons.light_mode_outlined,
                      value: c.lightening,
                      onChanged: c.updateLightening,
                    ),
                    EffectSliderRow(
                      label: 'Smooth',
                      icon: Icons.blur_on_rounded,
                      value: c.smoothness,
                      onChanged: c.updateSmoothness,
                    ),
                    EffectSliderRow(
                      label: 'Warmth',
                      icon: Icons.favorite_border_rounded,
                      value: c.redness,
                      onChanged: c.updateRedness,
                    ),
                    EffectSliderRow(
                      label: 'Detail',
                      icon: Icons.hd_outlined,
                      value: c.sharpness,
                      onChanged: c.updateSharpness,
                    ),
                    EffectSliderRow(
                      label: 'Color',
                      icon: Icons.palette_outlined,
                      value: c.colorStrength,
                      onChanged: c.updateColorStrength,
                    ),
                    EffectSliderRow(
                      label: 'Skin safe',
                      icon: Icons.face_retouching_natural_rounded,
                      value: c.skinProtect,
                      onChanged: c.updateSkinProtect,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
