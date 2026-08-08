import 'package:flutter/material.dart';

class right_icon_button extends StatelessWidget {
  final IconData icon;
  const right_icon_button({
    super.key,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      icon: Icon(
        icon,
        color: Color(0xff8219f1),
        size: 25,
      ),
    );
  }
}
