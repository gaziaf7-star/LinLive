import 'package:flutter/material.dart';

import 'package:get/get.dart';

import '../../../../constants/layout_constant.dart';
import '../../../../widgets/after/castom appbar.dart';
import '../../accountInfornation/views/widget/CastomBtton.dart';
import 'EditProfile.dart';
import 'coun.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Signaturepage extends StatelessWidget {
  Signaturepage({super.key});
  final TextEditingController _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: ('Signature').appTr,
      ),
      body: Column(
        children: [
          SizedBox(
            height: kHeight * 0.02,
          ),
          WordCountTextField(),
          SizedBox(
            height: kHeight * 0.02,
          ),
          CastomAppButton(
            onPressed: () {
              String name = _controller.text.trim(); // Get the input text
              Get.to(
                Editprofile(),
                arguments: {'name': name},
                transition: Transition.rightToLeft,
              );
            },
            buttonText: ('Submit').appTr,
          ),
        ],
      ),
    );
  }
}
