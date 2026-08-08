import 'package:flutter/material.dart';

import '../../../../widgets/after/castom appbar.dart';
import 'BackPackStore.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Backpack extends StatelessWidget {
  const Backpack({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F5F9),
      appBar: CustomAppBar(
        title: ('Back Pack').appTr,
      ),
      body: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Backpackstore(),
      ),
    );
  }
}
