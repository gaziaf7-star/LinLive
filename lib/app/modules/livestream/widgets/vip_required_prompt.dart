import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../svip/views/svip_view.dart';
import '../../../localization/app_localizer.dart';

bool _vipRequiredPromptOpen = false;

Future<void> showVipRequired(String featureName) async {
  if (_vipRequiredPromptOpen || Get.isDialogOpen == true) return;
  _vipRequiredPromptOpen = true;
  try {
    await Get.dialog<void>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF11152A),
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              const Icon(Icons.workspace_premium_rounded,
                  color: Color(0xFFFFD76A), size: 42),
              const SizedBox(height: 10),
              Text(
                ('VIP access required').appTr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                ('Activate VIP to unlock $featureName').appTr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Get.back<void>();
                    Get.to(() => SvipView());
                  },
                  icon: const Icon(Icons.diamond_rounded),
                  label: Text(('View VIP').appTr),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    _vipRequiredPromptOpen = false;
  }
}
