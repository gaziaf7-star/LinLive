import 'package:flutter/cupertino.dart';

class message_left_icon extends StatelessWidget {
  final String image;
  const message_left_icon({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 8.0,
      ),
      child: Image(
        image: AssetImage(image),
        height: 20,
      ),
    );
  }
}
