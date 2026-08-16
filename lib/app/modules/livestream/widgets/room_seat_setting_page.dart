import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class RoomSeatSettingResult {
  final int seatCount;
  final int roomLayout;

  const RoomSeatSettingResult({
    required this.seatCount,
    required this.roomLayout,
  });
}

class RoomSeatSettingPage extends StatefulWidget {
  final List<int> seatOptions;
  final int initialSeatCount;
  final int initialLayout;

  const RoomSeatSettingPage({
    super.key,
    required this.seatOptions,
    required this.initialSeatCount,
    required this.initialLayout,
  });

  @override
  State<RoomSeatSettingPage> createState() => _RoomSeatSettingPageState();
}

class _RoomSeatSettingPageState extends State<RoomSeatSettingPage> {
  late int _seatCount;
  late int _layout;

  @override
  void initState() {
    super.initState();
    _seatCount = widget.initialSeatCount;
    _layout = widget.initialLayout;
  }

  int _maxLayoutForSeats(int seats) {
    if (seats == 9) return 3;
    if (seats == 12) return 4;
    return 0;
  }

  void _select(int seats) {
    setState(() {
      _seatCount = seats;
      _layout = _layout.clamp(0, _maxLayoutForSeats(seats)).toInt();
    });
  }

  void _confirm() {
    Get.back(
      result: RoomSeatSettingResult(
        seatCount: _seatCount,
        roomLayout: _layout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff050505),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xff050505),
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Text(
          ('Choose party mode').appTr,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Text(
                ('Number of mics').appTr,
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                ('Switching the number of mics, the position of the user may change.')
                    .appTr,
                style: GoogleFonts.roboto(
                  color: const Color(0xff9b9b9b),
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                physics: const BouncingScrollPhysics(),
                itemCount: widget.seatOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (context, index) {
                  final seat = widget.seatOptions[index];
                  final active = seat == _seatCount;
                  return _seatCard(seat, active);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 8, 36, 18),
              child: GestureDetector(
                onTap: _confirm,
                child: Container(
                  height: 56,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xffffe20a),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    ('Confirm').appTr,
                    style: GoogleFonts.roboto(
                      color: const Color(0xff3f3b00),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
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

  Widget _seatCard(int seatCount, bool active) {
    final int columns = seatCount >= 15 ? 5 : seatCount >= 12 ? 4 : 3;
    final int rows = (seatCount / columns).ceil();

    return GestureDetector(
      onTap: () => _select(seatCount),
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xff303030),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? const Color(0xffffe20a) : const Color(0xff656565),
                  width: active ? 2 : 1.2,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final spacing = 6.0;
                  final dot = ((constraints.maxWidth - (columns - 1) * spacing) /
                      columns)
                      .clamp(16.0, 32.0)
                      .toDouble();
                  return Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: spacing,
                      runSpacing: spacing,
                      children: List.generate(
                        rows * columns,
                            (index) => index < seatCount
                            ? Container(
                          width: dot,
                          height: dot,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xff666666),
                          ),
                          child: Icon(
                            Icons.weekend_rounded,
                            color: const Color(0xffa4a4a4),
                            size: dot * .55,
                          ),
                        )
                            : SizedBox(width: dot, height: dot),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: active ? const Color(0xffffe20a) : const Color(0xff9a9a9a),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$seatCount',
              style: GoogleFonts.roboto(
                color: active ? const Color(0xff282300) : const Color(0xff2f2f2f),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
