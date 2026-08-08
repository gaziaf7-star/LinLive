import 'package:flutter/cupertino.dart';

class bottomfasttext extends StatelessWidget {
  String text;
  Color color;

  bottomfasttext({
    required this.text,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 20, fontFamily: 'Itim'),
    );
  }
}
