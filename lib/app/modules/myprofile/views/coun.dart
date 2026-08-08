import 'package:flutter/material.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class WordCountTextField extends StatefulWidget {
  const WordCountTextField({super.key});

  @override
  State<WordCountTextField> createState() => _WordCountTextFieldState();
}

class _WordCountTextFieldState extends State<WordCountTextField> {
  final TextEditingController _controller = TextEditingController();
  int letterCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_countLetters);
  }

  void _countLetters() {
    final text = _controller.text;
    setState(() {
      // Count all characters except spaces, tabs, and newlines
      letterCount = text.replaceAll(RegExp(r'\s+'), '').length;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_countLetters);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double kWeight = MediaQuery.of(context).size.width;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: kWeight * 0.03),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xff8A4CF7)),
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              maxLines: null,
              minLines: 3,
              keyboardType: TextInputType.multiline,
              decoration:  InputDecoration(
                hintText: ('Type here...').appTr,
                border: InputBorder.none,
              ),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 25.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$letterCount/60',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
