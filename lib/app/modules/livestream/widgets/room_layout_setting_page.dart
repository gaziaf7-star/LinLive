import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class RoomLayoutSettingPage extends StatefulWidget {
  final int seatCount;
  final int initialLayout;
  final int layoutCount;

  const RoomLayoutSettingPage({
    super.key,
    required this.seatCount,
    required this.initialLayout,
    required this.layoutCount,
  });

  @override
  State<RoomLayoutSettingPage> createState() => _RoomLayoutSettingPageState();
}

class _RoomLayoutSettingPageState extends State<RoomLayoutSettingPage> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLayout
        .clamp(0, widget.layoutCount - 1)
        .toInt();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff202020),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          ('Room Layout').appTr,
          style: GoogleFonts.roboto(
            color: const Color(0xff171717),
            fontSize: 21,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              itemCount: widget.layoutCount,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final active = _selected == index;
                return GestureDetector(
                  onTap: () => setState(() => _selected = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: const Color(0xff22263f),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active
                            ? const Color(0xff6547ff)
                            : const Color(0xff343a5b),
                        width: active ? 2.5 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _layoutPreview(index),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 10,
                          child: Text(
                            ('Layout ${index + 1}').appTr,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (active)
                          const Positioned(
                            right: 10,
                            top: 10,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xff7864ff),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: GestureDetector(
                onTap: () => Get.back(result: _selected),
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xff5942f5),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text(
                    ('Confirm').appTr,
                    style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _layoutPreview(int layoutIndex) {
    final int previewCount = widget.seatCount.clamp(1, 12).toInt();
    final int columns = layoutIndex % 2 == 0 ? 4 : 3;

    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          previewCount,
              (index) => Container(
            height: 22,
            width: index == 0 ? 30 : 22,
            margin: index != 0 && index % columns == 0
                ? const EdgeInsets.only(left: 2)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(index == 0 ? 10 : 22),
              color: index == 0
                  ? Colors.white.withOpacity(.9)
                  : Colors.white.withOpacity(.30),
            ),
            child: Icon(
              index == 0 ? Icons.person_rounded : Icons.weekend_rounded,
              color: index == 0
                  ? const Color(0xff555a77)
                  : Colors.white.withOpacity(.65),
              size: index == 0 ? 15 : 12,
            ),
          ),
        ),
      ),
    );
  }
}
