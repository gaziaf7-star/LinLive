import 'package:flutter/material.dart';

import 'mall_items_page.dart';

/// Optional convenience wrapper. Direct call korte chaile:
/// Get.to(() => const EntryMallView());
/// Mall grid theke tap korle MallCategoryPage nijei MallItemsPage
/// call kore, tai ei file na thakleo চলবে — kintu রেখে দিলাম jate
/// onno kothao "Entrance Show" page-e navigate korte hole ei ekta
/// line likhleই hoy.
class EntryMallView extends StatelessWidget {
  const EntryMallView({super.key});

  @override
  Widget build(BuildContext context) {
    return const MallItemsPage(
      title: 'Entrance Show',
      apiType: 'Entry Care',
    );
  }
}