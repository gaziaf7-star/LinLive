import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'color_constants.dart';

class kLoadingIndicator extends StatelessWidget {
  const kLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return SpinKitDualRing(size: 40, color: kPrimaryColor);
  }

  //after add firebase
}
