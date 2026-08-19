import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'effect_widgets.dart';
import 'video_effect_models.dart';
import 'video_effects_controller.dart';

class PresetsEffectPage extends StatefulWidget {
  const PresetsEffectPage({
    super.key,
    required this.controller,
  });

  final VideoEffectsController controller;

  @override
  State<PresetsEffectPage> createState() => _PresetsEffectPageState();
}

class _PresetsEffectPageState extends State<PresetsEffectPage> {
  int category = 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Column(
          children: [
            SizedBox(
              height: 45,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: List.generate(
                  const ['Favorites', 'New', 'Basic', 'Studio'].length,
                      (index) => SectionChip(
                    label: const ['Favorites', 'New', 'Basic', 'Studio'][index],
                    selected: category == index,
                    onTap: () => setState(() => category = index),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 16),
            SizedBox(
              height: 124,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  EffectLookCard(
                    look: noEffectLook,
                    selected: widget.controller.selectedLookId == 'none',
                    icon: Icons.block_rounded,
                    onTap: () => widget.controller.applyLook(noEffectLook),
                  ),
                  ...professionalPresets.map(
                        (look) => EffectLookCard(
                      look: look,
                      selected: widget.controller.selectedLookId == look.id,
                      onTap: () => widget.controller.applyLook(look),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF71E8D6),
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Realtime preset is applied to the Agora camera stream.',
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
