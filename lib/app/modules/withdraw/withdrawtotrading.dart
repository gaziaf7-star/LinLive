import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../constants/layout_constant.dart';
import '../../../widgets/after/CastomText.dart';
import '../../../widgets/after/castom appbar.dart';
import '../../../widgets/setheight.dart';
import '../accountInfornation/views/widget/CastomBtton.dart';
import 'controllers/withdraw_controller.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Withdrawtotrading extends StatelessWidget {
  const Withdrawtotrading({super.key});

  @override
  Widget build(BuildContext context) {
    WithdrawController withdrawController = Get.put(WithdrawController());
    return Scaffold(
        appBar: CustomAppBar(
          title: ('Withdraw to Trading').appTr,
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                child: Castontext(text: 'Earning to Trading Amount'),
              ),
              SetHeight(heightSet: 0.01),
              Center(
                child: SizedBox(
                  width: kWeight * 0.9,
                  child: TextFormField(
                    keyboardType: TextInputType.number,
                    controller: withdrawController.tradeAmount,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 20,
                        color: Colors.black),
                    cursorColor: Colors.black87,
                    decoration: InputDecoration(
                      hintText: ('Enter amount').appTr,
                      prefixIcon: Icon(
                        Icons.diamond,
                        color: Color(0xff813aec),
                      ),
                      hintStyle: GoogleFonts.lato(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                      fillColor: Colors.grey.withOpacity(0.3),
                      filled: true,
                      border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(10)),
                      disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              SetHeight(heightSet: 0.03),
              Obx(() {
                return Center(
                  child: CastomAppButton(
                    fastColor: withdrawController.isTradeFormFilled.value
                        ? const Color(0xff8A4CF7)
                        : CupertinoColors.inactiveGray,
                    secondColor: withdrawController.isTradeFormFilled.value
                        ? const Color(0xffB460F0)
                        : Colors.grey,
                    onPressed: withdrawController.isTradeFormFilled.value
                        ? () {
                            withdrawController.withdrawToTradePost();
                          }
                        : null,
                    buttonText: '',
                    child: withdrawController.isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        :  Text(
                            ("Sure").appTr,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                );
              }),
              SetHeight(heightSet: 0.02),
            ],
          ),
        ));
  }
}
