import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SetHeight extends StatelessWidget {
  final double heightSet;
  const SetHeight({
    required this.heightSet,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: Get.height * heightSet);
  }
}
