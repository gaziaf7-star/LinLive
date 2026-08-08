import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_localizer.dart';

class AppLanguagePage extends StatelessWidget {
  const AppLanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLanguageController controller = AppLanguageController.to;

    return Scaffold(
      backgroundColor: const Color(0xfffaf7ff),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xff8A4CF7),
        foregroundColor: Colors.white,
        title: Obx(() {
          // Read the Rx directly inside Obx so GetX can track it.
          controller.currentLocaleKey.value;

          return Text(
            'Choose Language'.appTr,
            style: const TextStyle(fontWeight: FontWeight.w700),
          );
        }),
      ),
      body: Obx(() {
        // IMPORTANT:
        // Read the observable before returning ListView. ListView's itemBuilder
        // is lazy, so reading the Rx only inside itemBuilder does not register
        // it as a dependency of this Obx.
        final String selectedLocaleKey =
            controller.currentLocaleKey.value;

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: AppLanguageController.languageOptions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final AppLanguageOption option =
            AppLanguageController.languageOptions[index];

            return _LanguageTile(
              option: option,
              selected: selectedLocaleKey == option.key,
              onTap: () async {
                await controller.changeLanguage(option.key);
              },
            );
          },
        );
      }),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppLanguageOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xff8A4CF7)
                  : Colors.grey.withOpacity(0.20),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
              BoxShadow(
                color: const Color(0xff8A4CF7).withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              Text(
                option.flag,
                style: const TextStyle(fontSize: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.nativeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff2d2340),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xff8a8198),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey<bool>(selected),
                  color: selected
                      ? const Color(0xff8A4CF7)
                      : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
