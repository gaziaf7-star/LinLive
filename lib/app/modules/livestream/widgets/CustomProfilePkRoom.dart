import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';

class CustomProfilePkRoom extends StatelessWidget {
  const CustomProfilePkRoom({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: Colors.blue, width: 2),
        borderRadius:
        BorderRadius.circular(100),
        color: Color(0xff5584BA),
      ),
      child: ClipRRect(
        borderRadius:
        BorderRadius.circular(300),
        child: CachedNetworkImage(
          imageUrl:
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSrVN9H11wCam0PY3Wp44gEjVOWihP2BNyltg&s',
          height: Get.height * 0.04,
          width: Get.height * 0.04,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}