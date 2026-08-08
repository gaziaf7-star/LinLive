import 'package:meetlivepro/app/localization/app_localizer.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:tadolive/constants/constants.dart';
// import 'package:tadolive/constants/image_const/image_conost.dart';
//
// import '../../../../constants/constants.dart';
// import '../../../../constants/image_const/image_conost.dart';
// import '../../../../constants/layout_constant.dart';
// import '../../../../widgets/after/CastomText.dart';
// import '../../../../widgets/after/castom appbar.dart';
// import '../../informationcollection/views/informationcollection_view.dart';
// import 'agency_view.dart';
//
// class Agencyoption extends StatelessWidget {
//   const Agencyoption({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: CustomAppBar(
//         title: ('Create Agency').appTr,
//       ),
//       body: Column(
//         children: [
//           Center(
//             child: InkWell(
//               onTap: () {
//                 Get.to(InformationcollectionView(),
//                     transition: Transition.rightToLeft);
//               },
//               child: Container(
//                 padding: EdgeInsets.symmetric(
//                   vertical: kHeight * 0.02,
//                 ),
//                 margin: EdgeInsets.symmetric(
//                     vertical: kHeight * 0.03, horizontal: kWeight * 0.04),
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(10),
//                   gradient: LinearGradient(
//                     colors: [
//                       Color(0xffb5a7fe),
//                       Color(0xffb5a7fe),
//                     ],
//                     begin: Alignment.topCenter,
//                     end: Alignment.bottomCenter,
//                   ),
//                 ),
//                 child: Column(
//                   children: [
//                     Container(
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(10),
//                         gradient: LinearGradient(
//                           colors: [
//                             Color(0xff2c0375),
//                             Color(0xff41026e),
//                           ],
//                           begin: Alignment.topCenter,
//                           end: Alignment.bottomCenter,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.white.withOpacity(0.2),
//                             spreadRadius: 2,
//                             blurRadius: 10,
//                             offset: Offset(0, 5),
//                           ),
//                         ],
//                       ),
//                       child: ClipRRect(
//                         borderRadius: BorderRadius.circular(6),
//                         child: Image.asset(
//                           appLogo,
//                           width: kHeight * 0.05,
//                           height: kHeight * 0.05,
//                           fit: BoxFit.cover,
//                         ),
//                       ),
//                     ),
//                     SizedBox(
//                       height: 6,
//                     ),
//                     GestureDetector(
//                       onTap: () {
//                         final status =
//                             homeController.agencyListData['Agency']['status'];
//
//                         if (status == 'pending') {
//                           print('');
//                         } else {
//                           Get.to(AgencyView(),
//                               transition: Transition.rightToLeft);
//                         }
//                       },
//                       child: Container(
//                         padding:
//                             EdgeInsets.symmetric(horizontal: 20, vertical: 2),
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(50),
//                           color: Color(0xff8A4CF7),
//                         ),
//                         child: Padding(
//                           padding: const EdgeInsets.only(bottom: 3.0),
//                           child: Castontext(
//                               fontWeight: FontWeight.w600,
//                               fontSize: kHeight * 0.013,
//                               textColor: Colors.white,
//                               text:
//                                   '${homeController.agencyListData['Agency']?['status']}'),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           Castontext(
//               fontSize: kHeight * 0.012, text: 'Please contact official admin'),
//           SizedBox(
//             height: kHeight * .01,
//           ),
//         ],
//       ),
//     );
//   }
// }
