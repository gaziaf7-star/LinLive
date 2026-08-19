import 'package:flutter/material.dart';

import 'effect_widgets.dart';
import 'video_effect_models.dart';
import 'video_effects_controller.dart';

class MakeupEffectPage extends StatefulWidget {
  const MakeupEffectPage({
    super.key,
    required this.controller,
  });

  final VideoEffectsController controller;

  @override
  State<MakeupEffectPage> createState() => _MakeupEffectPageState();
}

class _MakeupEffectPageState extends State<MakeupEffectPage> {
  int category = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Column(
          children: [
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: List.generate(
                  const ['New', 'Basic', 'Glow', 'Studio'].length,
                      (index) => SectionChip(
                    label: const ['New', 'Basic', 'Glow', 'Studio'][index],
                    selected: category == index,
                    onTap: () => setState(() => category = index),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 18),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: makeupLooks.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 10,
                  childAspectRatio: .82,
                ),
                itemBuilder: (context, index) {
                  final look = makeupLooks[index];
                  return EffectLookCard(
                    look: look,
                    selected: widget.controller.selectedLookId == look.id,
                    icon: index.isEven
                        ? Icons.brush_rounded
                        : Icons.face_retouching_natural_rounded,
                    onTap: () => widget.controller.applyLook(look),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
