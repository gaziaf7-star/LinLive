import 'package:flutter/material.dart';

class giftContainer extends StatelessWidget {
  final Color bodercolor;

  giftContainer({
    super.key,
    required this.bodercolor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Color(0x85efa2f4),
            Color(0xcadd6af0),
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: bodercolor,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              height: 2,
            ),
            Image(
              image: AssetImage('assets/images/cake.png'),
              height: 40,
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -5,
                  right: 12,
                  child: InkWell(
                    onTap: () {},
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: Image(
                        image: AssetImage('assets/images/profile pic.jpg'),
                        height: 22,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  child: Image(
                    image: AssetImage(
                        'assets/images/images-removebg-preview (1).png'),
                    height: 30,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
