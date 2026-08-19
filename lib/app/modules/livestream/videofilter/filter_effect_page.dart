import 'package:flutter/material.dart';

import 'effect_widgets.dart';
import 'video_effect_models.dart';
import 'video_effects_controller.dart';

class FilterEffectPage extends StatefulWidget {
  const FilterEffectPage({
    super.key,
    required this.controller,
  });

  final VideoEffectsController controller;

  @override
  State<FilterEffectPage> createState() => _FilterEffectPageState();
}

class _FilterEffectPageState extends State<FilterEffectPage> {
  int category = 1;

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
                  const ['Favorites', 'Hot', 'Portrait', 'Movie'].length,
                      (index) => SectionChip(
                    label: const ['Favorites', 'Hot', 'Portrait', 'Movie'][index],
                    selected: category == index,
                    onTap: () => setState(() => category = index),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 14),
            SizedBox(
              height: 124,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  EffectLookCard(
                    look: noEffectLook,
                    selected: c.selectedLookId == 'none',
                    icon: Icons.block_rounded,
                    onTap: () => c.applyLook(noEffectLook),
                  ),
                  ...colorFilterLooks.map(
                        (look) => EffectLookCard(
                      look: look,
                      selected: c.selectedLookId == look.id,
                      icon: Icons.filter_vintage_rounded,
                      onTap: () => c.applyLook(look),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: EffectSliderRow(
                label: 'Intensity',
                icon: Icons.tune_rounded,
                value: c.filterStrength,
                onChanged: c.updateFilterStrength,
              ),
            ),
          ],
        );
      },
    );
  }
}
