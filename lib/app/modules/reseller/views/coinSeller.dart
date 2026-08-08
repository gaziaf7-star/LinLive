import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class CoinSellerPAge extends StatelessWidget {
  const CoinSellerPAge({super.key});

  static const Color kAppColor1 = Color(0xFFF80230);
  static const Color kAppColor2 = Color(0xFFFD375D);
  static const Color kBlue = Color(0xFF4169FF);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F2F6),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(h * 0.065),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kAppColor1,
                kAppColor2,
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                SizedBox(width: w * 0.02),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: Text(
                    ("BD Manager Center").appTr,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: w * 0.042,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: w * 0.13),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.035,
          vertical: h * 0.018,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _profileHeader(w, h),
            SizedBox(height: h * 0.018),


          ],
        ),
      ),
    );
  }

  Widget _profileHeader(double w, double h) {
    return Row(
      children: [
        Container(
          height: w * 0.13,
          width: w * 0.13,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFC371),
                Color(0xFFFF5F6D),
              ],
            ),
          ),
          child: const CircleAvatar(
            backgroundImage: NetworkImage(
              "https://i.pravatar.cc/150?img=12",
            ),
          ),
        ),
        SizedBox(width: w * 0.025),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    ("Lin Live").appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: w * 0.04,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: w * 0.012),
                  Container(
                    width: w * 0.045,
                    height: w * 0.045,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E90FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.male_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                  SizedBox(width: w * 0.01),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.018,
                      vertical: h * 0.004,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4169FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ("BD Manager/Admin/Superadmin").appTr,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: w * 0.021,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: h * 0.004),
              Text(
                ("ID: 10031").appTr,
                style: GoogleFonts.poppins(
                  color: Colors.black45,
                  fontSize: w * 0.027,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _salaryCard({
    required double w,
    required double h,
    required IconData icon,
    required Color iconColor,
    required String amount,
    required String title,
  }) {
    return Container(
      height: h * 0.13,
      padding: EdgeInsets.all(w * 0.035),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Transform.rotate(
              angle: -0.35,
              child: Icon(
                icon,
                color: iconColor,
                size: w * 0.075,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  amount,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFE88435),
                    fontSize: w * 0.052,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: h * 0.006),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontSize: w * 0.026,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallInfoCard({
    required double w,
    required double h,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subTitle,
  }) {
    return Container(
      height: h * 0.092,
      padding: EdgeInsets.symmetric(horizontal: w * 0.045),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: w * 0.105,
            width: w * 0.105,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: w * 0.06,
            ),
          ),
          SizedBox(width: w * 0.035),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontSize: w * 0.032,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subTitle,
                style: GoogleFonts.poppins(
                  color: Colors.black54,
                  fontSize: w * 0.026,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required double w,
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    return SizedBox(
      width: w * 0.22,
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: w * 0.068,
          ),
          SizedBox(height: w * 0.018),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: w * 0.026,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}