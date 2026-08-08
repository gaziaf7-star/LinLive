import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/layout_constant.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class ExchangeSuccessPage extends StatelessWidget {
  final int exchangedAmount;
  final int receivedCoins;
  final String message;

  const ExchangeSuccessPage({
    super.key,
    required this.exchangedAmount,
    required this.receivedCoins,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f4ff),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(kWeight * 0.060),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(kWeight * 0.060),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 92,
                      width: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xff7C45BC),
                            Color(0xffcdaafc),
                            Color(0xffade8f0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff7C45BC).withOpacity(0.30),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 54,
                      ),
                    ),
                    SizedBox(height: kHeight * 0.030),
                    Text(
                      ('Exchange Successful').appTr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: kHeight * 0.010),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: kHeight * 0.030),
                    _successRow(
                      title: ('Exchanged Receive Coins').appTr,
                      value: exchangedAmount.toString(),
                    ),
                    SizedBox(height: kHeight * 0.012),
                    _successRow(
                      title: ('Received Coins').appTr,
                      value: receivedCoins.toString(),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: kHeight * 0.058,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xff7C45BC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    ('Back to Exchange').appTr,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _successRow({
    required String title,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: kWeight * 0.040,
        vertical: kHeight * 0.014,
      ),
      decoration: BoxDecoration(
        color: const Color(0xfff7f4ff),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffeadfff)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: const Color(0xff7C45BC),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}