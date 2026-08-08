import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/color_constants.dart';
import '../../../../../constants/layout_constant.dart';
import '../../../../../widgets/after/CastomText.dart';
import '../LoginPassword.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';

class CustomSettingOption extends StatelessWidget {
  const CustomSettingOption({
    super.key,
    this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: ListTile(
        title: Text(
          ('Account and security').appTr,
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w400,
            fontSize: kHeight * 0.016,
          ),
        ),
        trailing: SvgPicture.asset(
          'assets/audio_live/arrow_forward_ios_24dp_E3E3E3_FILL0_wght100_GRAD0_opsz24.svg',
          width: kHeight * 0.024,
          color: kAppColor,
          height: kHeight * 0.024,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        visualDensity: VisualDensity.comfortable,
        onTap: onPressed ?? () => Get.to(() => LoginPassword()),
      ),
    );
  }
}

class CastomSettingOption extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const CastomSettingOption({
    super.key,
    required this.text,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        text,
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w400,
          fontSize: kHeight * 0.016,
        ),
      ),
      trailing: SvgPicture.asset(
        'assets/audio_live/arrow_forward_ios_24dp_E3E3E3_FILL0_wght100_GRAD0_opsz24.svg',
        width: kHeight * 0.024,
        color: kAppColor,
        height: kHeight * 0.024,
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      visualDensity: VisualDensity.comfortable,
      onTap: onPressed,
    );
  }
}

class CastomSettingOption1 extends StatelessWidget {
  final String text;
  final String secoundText;
  final VoidCallback? onPressed;
  const CastomSettingOption1({
    super.key,
    required this.text,
    this.onPressed,
    required this.secoundText,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        text,
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w400,
          fontSize: kHeight * 0.016,
        ),
      ),
      trailing: Castontext(
          fontSize: kHeight * 0.014,
          textColor: Colors.black.withOpacity(.5),
          text: secoundText),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 8),
      visualDensity: VisualDensity.comfortable,
      onTap: onPressed,
    );
  }
}
