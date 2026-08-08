import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../constants/color_constants.dart';
import '../../../../constants/layout_constant.dart';
import '../../bottomnav/views/bottomnav_view.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class TransactionSuccessView extends StatelessWidget {
  const TransactionSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xffb5a7fe),
              Color(0xffffffff),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Animation Container
              Container(
                height: kHeight * 0.15,
                width: kHeight * 0.15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade50,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: FaIcon(
                  FontAwesomeIcons.circleCheck,
                  size: kHeight * 0.08,
                  color: Colors.green.shade600,
                ),
              ),
              
              SizedBox(height: kHeight * 0.04),
              
              // Success Title
              Text(
                ('Transaction Successful!').appTr,
                style: GoogleFonts.roboto(
                  fontSize: kHeight * 0.028,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: kHeight * 0.02),
              
              // Success Message
              Padding(
                padding: EdgeInsets.symmetric(horizontal: kWeight * 0.08),
                child: Text(
                  ('Your transaction has been completed successfully. Thank you for your purchase!').appTr,
                  style: GoogleFonts.roboto(
                    fontSize: kHeight * 0.018,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              SizedBox(height: kHeight * 0.06),
              
              // Transaction Details Card
              Container(
                margin: EdgeInsets.symmetric(horizontal: kWeight * 0.06),
                padding: EdgeInsets.all(kHeight * 0.025),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.receipt,
                          color: kAppColor,
                          size: kHeight * 0.022,
                        ),
                        SizedBox(width: kWeight * 0.03),
                        Text(
                          ('Transaction Details').appTr,
                          style: GoogleFonts.roboto(
                            fontSize: kHeight * 0.020,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: kHeight * 0.02),
                    
                    Divider(color: Colors.grey.shade200),
                    
                    SizedBox(height: kHeight * 0.02),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ('Status:').appTr,
                          style: GoogleFonts.roboto(
                            fontSize: kHeight * 0.016,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: kWeight * 0.03,
                            vertical: kHeight * 0.005,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            ('Completed').appTr,
                            style: GoogleFonts.roboto(
                              fontSize: kHeight * 0.014,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: kHeight * 0.015),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ('Date:').appTr,
                          style: GoogleFonts.roboto(
                            fontSize: kHeight * 0.016,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          DateTime.now().toString().split(' ')[0],
                          style: GoogleFonts.roboto(
                            fontSize: kHeight * 0.016,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: kHeight * 0.06),
              
              // Go Back Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: kWeight * 0.06),
                child: SizedBox(
                  width: double.infinity,
                  height: kHeight * 0.06,
                  child: ElevatedButton(
                    onPressed: () {
                      Get.offAll(
                        () => BottomnavView(),
                        transition: Transition.fadeIn,
                        duration: Duration(milliseconds: 300),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAppColor,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: kAppColor.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.house,
                          size: kHeight * 0.020,
                          color: Colors.white,
                        ),
                        SizedBox(width: kWeight * 0.02),
                        Text(
                          ('Go to Home').appTr,
                          style: GoogleFonts.roboto(
                            fontSize: kHeight * 0.018,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: kHeight * 0.02),
              
              // Secondary Button
              Padding(
                padding: EdgeInsets.symmetric(horizontal: kWeight * 0.06),
                child: SizedBox(
                  width: double.infinity,
                  height: kHeight * 0.055,
                  child: OutlinedButton(
                    onPressed: () {
                      Get.back();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kAppColor,
                      side: BorderSide(color: kAppColor, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.arrowLeft,
                          size: kHeight * 0.018,
                          color: kAppColor,
                        ),
                        SizedBox(width: kWeight * 0.02),
                        Text(
                          ('Go Back').appTr,
                          style: GoogleFonts.roboto(
                            fontSize: kHeight * 0.016,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: kHeight * 0.04),
            ],
          ),
        ),
      ),
    );
  }
}
