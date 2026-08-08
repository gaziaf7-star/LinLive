import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/color_constants.dart';


import 'package:meetlivepro/app/localization/app_localizer.dart';
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  int _rating = 0;
  String? _comment;
  bool _anonymous = false;

  void _setRating(int value) {
    setState(() => _rating = value);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        title: Text(("ধন্যবাদ!").appTr,
            style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
        content: Text(("আপনার ফিডব্যাক জমা হয়েছে।").appTr,
            style: GoogleFonts.roboto(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(("ঠিক আছে").appTr, style: GoogleFonts.roboto()),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Get.back();
            },
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
            )),
        backgroundColor: kAppColor,
        elevation: 1,
        centerTitle: true,
        title: Text(("Feedback").appTr,
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            )),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                ("Rate your experience").appTr,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),

              // Rating Stars
              Row(
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => _setRating(i + 1),
                    child: Icon(Icons.star,
                        size: 32,
                        color: _rating >= i + 1
                            ? Colors.orange
                            : Colors.grey.shade300),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(("Write your feedback").appTr,
                  style: GoogleFonts.roboto(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),

              TextFormField(
                cursorColor: kAppColor,
                maxLines: 5,
                decoration: InputDecoration(
                    hintText: ("Type your comments...").appTr,
                    hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade100),
                    )),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return "Please enter some feedback";
                  }
                  return null;
                },
                onSaved: (v) => _comment = v,
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(("Submit as anonymous").appTr,
                      style: GoogleFonts.roboto(fontSize: 14)),
                  Switch(
                      value: _anonymous,
                      onChanged: (v) => setState(() => _anonymous = v)),
                ],
              ),

              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.zero,
                  ).copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => null,
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kAppColor, Color(0xFF2575FC)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(("Submit Feedback").appTr,
                          style: GoogleFonts.roboto(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
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
}
