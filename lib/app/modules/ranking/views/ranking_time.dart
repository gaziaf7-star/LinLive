import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/layout_constant.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class CountdownTimerWidget extends StatefulWidget {
  const CountdownTimerWidget({super.key});

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Duration remaining = Duration.zero;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _setInitialRemaining();
    startTimer();
  }

  void _setInitialRemaining() {
    final now = DateTime.now();
    // আগামী রাত 12টা (পরবর্তী দিন)
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    remaining = nextMidnight.difference(now);
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining.inSeconds > 0) {
        setState(() {
          remaining = remaining - const Duration(seconds: 1);
        });
      } else {
        // যখন কাউন্টডাউন শেষ হবে তখন আবার reset করবে পরবর্তী দিনের জন্য
        _setInitialRemaining();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${days.toString().padLeft(2, '0')} D '
        '${hours.toString().padLeft(2, '0')} H '
        '${minutes.toString().padLeft(2, '0')} M '
        '${seconds.toString().padLeft(2, '0')} S';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        ("Countdown : ${formatDuration(remaining)}").appTr,
        style: GoogleFonts.lato(
          color: Color(0xffffdf95),
          fontWeight: FontWeight.w500,
          fontSize: kHeight * 0.015,
        ),
      ),
    );
  }
}
