import 'package:flutter/material.dart';

import 'mall_items_page.dart';

/// Optional convenience wrapper. Direct call korte chaile:
/// Get.to(() => const FrameMallView());
/// Mall grid theke tap korle MallCategoryPage nijei MallItemsPage
/// call kore, tai ei file na thakleo চলবে — kintu রেখে দিলাম jate
/// onno kothao "Frame" page-e navigate korte hole ei ekta line likhleই hoy.
class FrameMallView extends StatelessWidget {
  const FrameMallView({super.key});

  @override
  Widget build(BuildContext context) {
    return const MallItemsPage(
      title: 'Frame',
      apiType: 'Frame',
    );
  }
}