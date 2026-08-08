// import 'dart:io';
//
// import 'package:agora_rtc_engine/agora_rtc_engine.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:tadolive/app/modules/livestream/controllers/livestream_controller.dart';
// import 'package:tadolive/app/services/agora_service.dart';
// import 'package:tadolive/constants/layout_constant.dart';
//
// import '../../../../constants/image_const/image_conost.dart';
// import '../../../../widgets/after/CastomText.dart';
// import '../../auth/controllers/auth_controller.dart';
//
// class GotoMultiLive extends StatefulWidget {
//   const GotoMultiLive({
//     super.key,
//   });
//
//   @override
//   State<GotoMultiLive> createState() => _GotoMultiLiveState();
// }
//
// class _GotoMultiLiveState extends State<GotoMultiLive> {
//   final AuthController _authController = Get.find();
//   final LivestreamController livestreamController = Get.find();
//   final TextEditingController _editingControllerStreamingTitle =
//       TextEditingController();
//   // final giftController = Get.put(GiftController());
//
//   // Agora Service
//   final AgoraService _agoraService = AgoraService();
//   bool isEngineReady = false;
//
//   @override
//   void initState() {
//     livestreamController.seatCount.value = 4;
//     super.initState();
//     initAgora();
//   }
//
//   Future<void> initAgora() async {
//     // AgoraService is already initialized on app startup
//     // Just verify it's ready
//     bool success = _agoraService.isInitialized && _agoraService.engine != null;
//
//     if (!success) {
//       print(
//           'GotoMultiLive: AgoraService not ready, attempting to initialize...');
//       success = await _agoraService.initializeEngine();
//     }
//
//     if (mounted) {
//       setState(() {
//         isEngineReady = success;
//       });
//     }
//
//     if (success) {
//       print('GotoMultiLive: Agora is ready');
//     } else {
//       print('GotoMultiLive: Failed to initialize Agora');
//     }
//   }
//
//   @override
//   void dispose() {
//     _editingControllerStreamingTitle.dispose();
//     super.dispose();
//   }
//
//   String backGroundImage = 'assets/images/backgroundimagewalparer.jpg';
//   String liveType = 'public';
//
//   @override
//   Widget build(BuildContext context) {
//     Size sizeHeigt = MediaQuery.of(context).size;
//     return Scaffold(
//       backgroundColor: Colors.transparent, // Camera pure full screen dekhabe
//       body: Stack(
//         children: [
//           // === FULL SCREEN CAMERA BACKGROUND ===
//           Positioned.fill(
//             child: Container(
//               decoration: backGroundImage == 'none'
//                   ? const BoxDecoration(
//                       gradient: LinearGradient(
//                         begin: Alignment.topCenter,
//                         end: Alignment.bottomLeft,
//                         colors: [
//                           Color(0xff774AA0),
//                           Color(0xff6964C2),
//                           Color(0xff1D1A49),
//                         ],
//                       ),
//                     )
//                   : BoxDecoration(
//                       image: DecorationImage(
//                         image: AssetImage(
//                           'assets/images/backgroundimagewalparer.jpg',
//                         ),
//                         fit: BoxFit.cover,
//                       ),
//                     ),
//             ),
//           ),
//
//           // === UI OVERLAY ===
//           SizedBox(
//             height: MediaQuery.of(context).size.height,
//             width: MediaQuery.of(context).size.width,
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   SizedBox(
//                     height: kHeight * 0.03,
//                   ),
//                   Container(
//                     alignment: Alignment.topRight,
//                     child: IconButton(
//                       icon: const Icon(Icons.close),
//                       color: Colors.white,
//                       padding: EdgeInsets.zero,
//                       onPressed: () {
//                         Get.back();
//                       },
//                     ),
//                   ),
//                   Stack(
//                     children: [
//                       InkWell(
//                           onTap: () {
//                             livestreamController.audioimagePicker();
//                           },
//                           child: Container(
//                             padding: EdgeInsets.symmetric(
//                                 vertical: kHeight * 0.006,
//                                 horizontal: kWeight * 0.02),
//                             margin: const EdgeInsets.symmetric(
//                                 horizontal: 18, vertical: 0),
//                             width: double.infinity,
//                             decoration: BoxDecoration(
//                               borderRadius: BorderRadius.circular(6),
//                               color: Colors.black38,
//                             ),
//                             child: Row(
//                               mainAxisAlignment: MainAxisAlignment.start,
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 livestreamController.audioImage.isEmpty
//                                     ? Container(
//                                         decoration: BoxDecoration(
//                                           borderRadius:
//                                               BorderRadius.circular(10),
//                                           gradient: LinearGradient(
//                                             colors: [
//                                               Color(0xff2c0375),
//                                               Color(0xff41026e),
//                                             ],
//                                             begin: Alignment.topCenter,
//                                             end: Alignment.bottomCenter,
//                                           ),
//                                           boxShadow: [
//                                             BoxShadow(
//                                               color:
//                                                   Colors.white.withOpacity(0.2),
//                                               spreadRadius: 2,
//                                               blurRadius: 10,
//                                               offset: Offset(0, 5),
//                                             ),
//                                           ],
//                                         ),
//                                         child: ClipRRect(
//                                           borderRadius:
//                                               BorderRadius.circular(10),
//                                           child: Image.asset(
//                                             appLogo,
//                                             width: kHeight * 0.078,
//                                             height: kHeight * 0.078,
//                                             fit: BoxFit.cover,
//                                           ),
//                                         ),
//                                       )
//                                     : Obx(() => Container(
//                                           decoration: BoxDecoration(
//                                               borderRadius:
//                                                   BorderRadius.circular(10)),
//                                           width: kWeight * 0.167,
//                                           child: ClipRRect(
//                                             borderRadius:
//                                                 BorderRadius.circular(10),
//                                             child: Image.file(
//                                               File(livestreamController
//                                                   .audioImage.value),
//                                               height: kHeight * 0.078,
//                                               fit: BoxFit.cover,
//                                             ),
//                                           ),
//                                         )),
//                                 SizedBox(
//                                   width: kWeight * 0.02,
//                                 ),
//                                 Column(
//                                   mainAxisAlignment: MainAxisAlignment.start,
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     SizedBox(
//                                       height: kHeight * 0.07,
//                                       width: kWeight * 0.6,
//                                       child: TextField(
//                                         style: const TextStyle(
//                                             color: Colors.white),
//                                         controller:
//                                             _editingControllerStreamingTitle,
//                                         decoration: InputDecoration(
//                                           border: InputBorder.none,
//                                           hintText: 'write live a title',
//                                           hintStyle: GoogleFonts.lato(
//                                             fontSize: kHeight * 0.015,
//                                             fontWeight: FontWeight.w600,
//                                             color: Colors.white,
//                                             fontStyle: FontStyle.italic,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(height: 5),
//                                   ],
//                                 ),
//                               ],
//                             ),
//                           )),
//                       Positioned(
//                         left: kWeight * 0.057,
//                         top: kHeight * 0.063,
//                         child: Container(
//                             padding: EdgeInsets.symmetric(
//                                 vertical: 3, horizontal: kWeight * 0.022),
//                             decoration: BoxDecoration(
//                                 borderRadius: BorderRadius.only(
//                                     bottomLeft: Radius.circular(10),
//                                     bottomRight: Radius.circular(10)),
//                                 color: Color(0xff704bfa).withOpacity(0.3)),
//                             child: Castontext(
//                                 textColor: Colors.white,
//                                 fontWeight: FontWeight.w500,
//                                 fontSize: kHeight * 0.01,
//                                 text: 'Cover photo')),
//                       ),
//                     ],
//                   ),
//                   SizedBox(
//                     height: kHeight * 0.02,
//                   ),
//                   livestreamController.seatCount.value == 4
//                       ? Container(
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.white10),
//                             color: Colors.black26,
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           height: sizeHeigt.height * .38,
//                           child: Row(
//                             crossAxisAlignment: CrossAxisAlignment
//                                 .stretch, // Full height stretch
//                             children: [
//                               // Left Camera Preview Part
//                               Expanded(
//                                 flex: 2,
//                                 child: ClipRRect(
//                                   borderRadius: const BorderRadius.only(
//                                     topLeft: Radius.circular(8),
//                                     bottomLeft: Radius.circular(8),
//                                   ),
//                                   child: isEngineReady &&
//                                           _agoraService.engine != null
//                                       ? AgoraVideoView(
//                                           controller: VideoViewController(
//                                             rtcEngine: _agoraService.engine!,
//                                             canvas: const VideoCanvas(
//                                               uid: 0,
//                                               renderMode: RenderModeType
//                                                   .renderModeHidden,
//                                               mirrorMode: VideoMirrorModeType
//                                                   .videoMirrorModeAuto,
//                                             ),
//                                           ),
//                                         )
//                                       : Container(
//                                           color: Colors.black54,
//                                           child: Center(
//                                             child: Column(
//                                               mainAxisAlignment:
//                                                   MainAxisAlignment.center,
//                                               children: [
//                                                 const CircularProgressIndicator(
//                                                   color: Colors.white,
//                                                 ),
//                                                 const SizedBox(height: 8),
//                                                 Text(
//                                                   isEngineReady
//                                                       ? 'Engine Ready'
//                                                       : 'Initializing...',
//                                                   style: const TextStyle(
//                                                       color: Colors.white,
//                                                       fontSize: 10),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ),
//                                 ),
//                               ),
//
//                               // Right Side - 3 Equal Height Boxes
//                               Expanded(
//                                 flex: 1,
//                                 child: Column(
//                                   children: [
//                                     Expanded(
//                                       child: Container(
//                                         decoration: BoxDecoration(
//                                           border: Border.all(
//                                             width: 1,
//                                             color: Colors.white,
//                                           ),
//                                         ),
//                                         child: Center(
//                                           child: Icon(
//                                             Icons.event_seat,
//                                             size: kHeight * 0.024,
//                                             color: Colors.white,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: Container(
//                                         decoration: const BoxDecoration(
//                                           border: Border(
//                                             left: BorderSide(
//                                                 color: Colors.white, width: 1),
//                                             right: BorderSide(
//                                                 color: Colors.white, width: 1),
//                                           ),
//                                         ),
//                                         child: Center(
//                                           child: Icon(
//                                             Icons.event_seat,
//                                             size: kHeight * 0.024,
//                                             color: Colors.white,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                     Expanded(
//                                       child: Container(
//                                         decoration: BoxDecoration(
//                                           border: Border.all(
//                                             width: 1,
//                                             color: Colors.white,
//                                           ),
//                                         ),
//                                         child: Center(
//                                           child: Icon(
//                                             Icons.event_seat,
//                                             size: kHeight * 0.024,
//                                             color: Colors.white,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         )
//                       : livestreamController.seatCount.value == 6
//                           ? Container(
//                               decoration: BoxDecoration(
//                                 border: Border.all(color: Colors.white10),
//                                 color: Colors.black26,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               height: sizeHeigt.height * .38,
//                               child: SizedBox(
//                                 height: sizeHeigt.height * .4,
//                                 child: Row(
//                                   children: [
//                                     Expanded(
//                                       flex: 2,
//                                       child: Column(
//                                         children: [
//                                           Expanded(
//                                             flex: 2,
//                                             child: SizedBox(
//                                               // height: double.infinity,
//                                               width: double.infinity,
//                                               child: isEngineReady &&
//                                                       _agoraService.engine !=
//                                                           null
//                                                   ? AgoraVideoView(
//                                                       controller:
//                                                           VideoViewController(
//                                                         rtcEngine: _agoraService
//                                                             .engine!,
//                                                         canvas:
//                                                             const VideoCanvas(
//                                                           uid: 0,
//                                                           renderMode: RenderModeType
//                                                               .renderModeHidden,
//                                                           mirrorMode:
//                                                               VideoMirrorModeType
//                                                                   .videoMirrorModeAuto,
//                                                         ),
//                                                       ),
//                                                     )
//                                                   : Container(
//                                                       color: Colors.black54,
//                                                       child: Center(
//                                                         child: Column(
//                                                           mainAxisAlignment:
//                                                               MainAxisAlignment
//                                                                   .center,
//                                                           children: [
//                                                             const CircularProgressIndicator(
//                                                               color:
//                                                                   Colors.white,
//                                                             ),
//                                                             const SizedBox(
//                                                                 height: 4),
//                                                             Text(
//                                                               isEngineReady
//                                                                   ? 'Ready'
//                                                                   : 'Loading...',
//                                                               style: const TextStyle(
//                                                                   color: Colors
//                                                                       .white,
//                                                                   fontSize: 8),
//                                                             ),
//                                                           ],
//                                                         ),
//                                                       ),
//                                                     ),
//                                             ),
//                                           ),
//                                           Expanded(
//                                             flex: 1,
//                                             child: Row(
//                                               children: [
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color: const Color(
//                                                       //     0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         top: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         bottom: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                     Expanded(
//                                       flex: 1,
//                                       child: Column(
//                                         children: [
//                                           Expanded(
//                                             flex: 1,
//                                             child: Container(
//                                               decoration: BoxDecoration(
//                                                 // color: const Color(0xff7665CF),
//                                                 border: Border.all(
//                                                   width: 1,
//                                                   color: Colors.white,
//                                                 ),
//                                               ),
//                                               child: Center(
//                                                 child: Icon(
//                                                   Icons.event_seat,
//                                                   size: kHeight * 0.024,
//                                                   color: Colors.white,
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                           Expanded(
//                                             flex: 1,
//                                             child: Container(
//                                               decoration: const BoxDecoration(
//                                                 // color: Color(0xff7665CF),
//                                                 border: Border(
//                                                   left: BorderSide(
//                                                     color: Colors.white,
//                                                     width: 1,
//                                                   ),
//                                                   right: BorderSide(
//                                                     color: Colors.white,
//                                                     width: 1,
//                                                   ),
//                                                 ),
//                                               ),
//                                               child: Center(
//                                                 child: Icon(
//                                                   Icons.event_seat,
//                                                   size: kHeight * 0.024,
//                                                   color: Colors.white,
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                           Expanded(
//                                             flex: 1,
//                                             child: Container(
//                                               decoration: BoxDecoration(
//                                                 // color:
//                                                 //     const Color(0xff7665CF),
//                                                 border: Border.all(
//                                                   width: 1,
//                                                   color: Colors.white,
//                                                 ),
//                                               ),
//                                               child: Center(
//                                                 child: Icon(
//                                                   Icons.event_seat,
//                                                   size: kHeight * 0.024,
//                                                   color: Colors.white,
//                                                 ),
//                                               ),
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             )
//                           : livestreamController.seatCount.value == 9
//                               ? Container(
//                                   decoration: BoxDecoration(
//                                     border: Border.all(color: Colors.white10),
//                                     color: Colors.black26,
//                                     borderRadius: BorderRadius.circular(8),
//                                   ),
//                                   height: sizeHeigt.height * .38,
//                                   child: Row(
//                                     children: [
//                                       Expanded(
//                                         flex: 1,
//                                         child: Column(
//                                           children: [
//                                             Expanded(
//                                               flex: 1,
//                                               child: Container(
//                                                 decoration: BoxDecoration(
//                                                   // color: const Color(0xff7665CF),
//                                                   border: Border.all(
//                                                     width: 1,
//                                                     color: Colors.white54,
//                                                   ),
//                                                 ),
//                                                 child: SizedBox(
//                                                   height: double.infinity,
//                                                   width: double.infinity,
//                                                   child: isEngineReady &&
//                                                           _agoraService
//                                                                   .engine !=
//                                                               null
//                                                       ? AgoraVideoView(
//                                                           controller:
//                                                               VideoViewController(
//                                                             rtcEngine:
//                                                                 _agoraService
//                                                                     .engine!,
//                                                             canvas:
//                                                                 const VideoCanvas(
//                                                               uid: 0,
//                                                               renderMode:
//                                                                   RenderModeType
//                                                                       .renderModeHidden,
//                                                               mirrorMode:
//                                                                   VideoMirrorModeType
//                                                                       .videoMirrorModeAuto,
//                                                             ),
//                                                           ),
//                                                         )
//                                                       : Container(
//                                                           color: Colors.black54,
//                                                           child: Center(
//                                                             child: Column(
//                                                               mainAxisAlignment:
//                                                                   MainAxisAlignment
//                                                                       .center,
//                                                               children: [
//                                                                 const CircularProgressIndicator(
//                                                                   color: Colors
//                                                                       .white,
//                                                                 ),
//                                                                 const SizedBox(
//                                                                     height: 4),
//                                                                 Text(
//                                                                   isEngineReady
//                                                                       ? 'Ready'
//                                                                       : 'Loading...',
//                                                                   style: const TextStyle(
//                                                                       color: Colors
//                                                                           .white,
//                                                                       fontSize:
//                                                                           8),
//                                                                 ),
//                                                               ],
//                                                             ),
//                                                           ),
//                                                         ),
//                                                 ),
//                                               ),
//                                             ),
//                                             Expanded(
//                                               flex: 1,
//                                               child: Container(
//                                                 decoration: const BoxDecoration(
//                                                   // color: Color(0xff7665CF),
//                                                   border: Border(
//                                                     left: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                     right: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 child: Center(
//                                                   child: Icon(
//                                                     Icons.event_seat,
//                                                     size: kHeight * 0.024,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                             Expanded(
//                                               flex: 1,
//                                               child: Container(
//                                                 decoration: BoxDecoration(
//                                                   // color:
//                                                   //     const Color(0xff7665CF),
//                                                   border: Border.all(
//                                                     width: 1,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                                 child: Center(
//                                                   child: Icon(
//                                                     Icons.event_seat,
//                                                     size: kHeight * 0.024,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 1,
//                                         child: Column(
//                                           children: [
//                                             Expanded(
//                                               flex: 1,
//                                               child: Container(
//                                                 decoration: const BoxDecoration(
//                                                   // color: Color(0xff7665CF),
//                                                   border: Border(
//                                                     top: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                     bottom: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 child: Center(
//                                                   child: Icon(
//                                                     Icons.event_seat,
//                                                     size: kHeight * 0.024,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                             Expanded(
//                                               flex: 1,
//                                               child: Container(
//                                                 decoration: const BoxDecoration(
//                                                   // color: Color(0xff7665CF),
//                                                   border: Border(
//                                                     left: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                     right: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 child: Center(
//                                                   child: Icon(
//                                                     Icons.event_seat,
//                                                     size: kHeight * 0.024,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                             Expanded(
//                                               flex: 1,
//                                               child: Container(
//                                                 decoration: const BoxDecoration(
//                                                   // color: Color(0xff7665CF),
//                                                   border: Border(
//                                                     top: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                     bottom: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                     right: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 child: Center(
//                                                   child: Icon(
//                                                     Icons.event_seat,
//                                                     size: kHeight * 0.024,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       Expanded(
//                                         flex: 1,
//                                         child: Column(
//                                           children: [
//                                             Expanded(
//                                               flex: 1,
//                                               child: Container(
//                                                 decoration: BoxDecoration(
//                                                   // color:
//                                                   //     const Color(0xff7665CF),
//                                                   border: Border.all(
//                                                     width: 1,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                                 child: Center(
//                                                   child: Icon(
//                                                     Icons.event_seat,
//                                                     size: kHeight * 0.024,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                             Expanded(
//                                               flex: 1,
//                                               child: Container(
//                                                 decoration: const BoxDecoration(
//                                                   // color:
//                                                   //     const Color(0xff7665CF),
//                                                   border: Border(
//                                                     right: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                     bottom: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 child: Center(
//                                                   child: Icon(
//                                                     Icons.event_seat,
//                                                     size: kHeight * 0.024,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                             Expanded(
//                                               flex: 1,
//                                               child: Container(
//                                                 decoration: const BoxDecoration(
//                                                   // color: Color(0xff7665CF),
//                                                   border: Border(
//                                                     right: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                     bottom: BorderSide(
//                                                       color: Colors.white,
//                                                       width: 1,
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 child: Center(
//                                                   child: Icon(
//                                                     Icons.event_seat,
//                                                     size: kHeight * 0.024,
//                                                     color: Colors.white,
//                                                   ),
//                                                 ),
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 )
//                               : livestreamController.seatCount.value == 15
//                                   ? Container(
//                                       decoration: BoxDecoration(
//                                         border:
//                                             Border.all(color: Colors.white10),
//                                         color: Colors.black26,
//                                         borderRadius: BorderRadius.circular(8),
//                                       ),
//                                       height: sizeHeigt.height * .42,
//                                       child: Row(
//                                         children: [
//                                           Expanded(
//                                             flex: 1,
//                                             child: Column(
//                                               children: [
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color: const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white54,
//                                                       ),
//                                                     ),
//                                                     child: SizedBox(
//                                                       height: double.infinity,
//                                                       width: double.infinity,
//                                                       child: isEngineReady &&
//                                                               _agoraService
//                                                                       .engine !=
//                                                                   null
//                                                           ? AgoraVideoView(
//                                                               controller:
//                                                                   VideoViewController(
//                                                                 rtcEngine:
//                                                                     _agoraService
//                                                                         .engine!,
//                                                                 canvas:
//                                                                     const VideoCanvas(
//                                                                   uid: 0,
//                                                                   renderMode:
//                                                                       RenderModeType
//                                                                           .renderModeHidden,
//                                                                   mirrorMode:
//                                                                       VideoMirrorModeType
//                                                                           .videoMirrorModeAuto,
//                                                                 ),
//                                                               ),
//                                                             )
//                                                           : Container(
//                                                               color: Colors
//                                                                   .black54,
//                                                               child: Center(
//                                                                 child: Column(
//                                                                   mainAxisAlignment:
//                                                                       MainAxisAlignment
//                                                                           .center,
//                                                                   children: [
//                                                                     const CircularProgressIndicator(
//                                                                       color: Colors
//                                                                           .white,
//                                                                     ),
//                                                                     const SizedBox(
//                                                                         height:
//                                                                             8),
//                                                                     Text(
//                                                                       isEngineReady
//                                                                           ? 'Engine Ready'
//                                                                           : 'Initializing Camera...',
//                                                                       style: const TextStyle(
//                                                                           color: Colors
//                                                                               .white,
//                                                                           fontSize:
//                                                                               12),
//                                                                     ),
//                                                                   ],
//                                                                 ),
//                                                               ),
//                                                             ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         left: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                           Expanded(
//                                             flex: 1,
//                                             child: Column(
//                                               children: [
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         top: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         bottom: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         left: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         top: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         bottom: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                           Expanded(
//                                             flex: 1,
//                                             child: Column(
//                                               children: [
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border(
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         bottom: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         bottom: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     )
//                                   : Expanded(
//                                       // height: 350,
//                                       // width: double.infinity,
//                                       child: Row(
//                                         children: [
//                                           Expanded(
//                                             flex: 1,
//                                             child: Column(
//                                               children: [
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: SizedBox(
//                                                       height: double.infinity,
//                                                       width: double.infinity,
//                                                       child: Image.asset(
//                                                           'assets/images/catimage.jpg'),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         left: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                           Expanded(
//                                             flex: 1,
//                                             child: Column(
//                                               children: [
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         top: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         bottom: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                           Expanded(
//                                             flex: 1,
//                                             child: Column(
//                                               children: [
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.red,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration: BoxDecoration(
//                                                       // color:
//                                                       //     const Color(0xff7665CF),
//                                                       border: Border.all(
//                                                         width: 1,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                           Expanded(
//                                             flex: 1,
//                                             child: Column(
//                                               children: [
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         top: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         top: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         bottom: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                                 Expanded(
//                                                   flex: 1,
//                                                   child: Container(
//                                                     decoration:
//                                                         const BoxDecoration(
//                                                       // color: Color(0xff7665CF),
//                                                       border: Border(
//                                                         right: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                         bottom: BorderSide(
//                                                           color: Colors.white,
//                                                           width: 1,
//                                                         ),
//                                                       ),
//                                                     ),
//                                                     child: Center(
//                                                       child: Icon(
//                                                         Icons.event_seat,
//                                                         size: kHeight * 0.024,
//                                                         color: Colors.white,
//                                                       ),
//                                                     ),
//                                                   ),
//                                                 ),
//                                               ],
//                                             ),
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                   SizedBox(height: kHeight * 0.01),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       InkWell(
//                         onTap: () {
//                           setState(() {
//                             livestreamController.seatCount.value = 4;
//                           });
//                         },
//                         child: Container(
//                           padding: EdgeInsets.symmetric(
//                               vertical: kHeight * 0.005,
//                               horizontal: kWeight * 0.02),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             color: livestreamController.seatCount.value == 4
//                                 ? Color(0xff6D59A1)
//                                 : Colors.black26,
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                             children: [
//                               Icon(
//                                 Icons.event_seat,
//                                 color: Colors.white,
//                                 size: kHeight * 0.015,
//                               ),
//                               const Text(
//                                 " 4",
//                                 style: TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       InkWell(
//                         onTap: () {
//                           setState(() {
//                             livestreamController.seatCount.value = 6;
//                           });
//                         },
//                         child: Container(
//                           padding: EdgeInsets.symmetric(
//                               vertical: kHeight * 0.005,
//                               horizontal: kWeight * 0.02),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             color: livestreamController.seatCount.value == 6
//                                 ? Color(0xff6D59A1)
//                                 : Colors.black26,
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                             children: [
//                               Icon(
//                                 Icons.event_seat,
//                                 color: Colors.white,
//                                 size: kHeight * 0.014,
//                               ),
//                               const Text(
//                                 " 6",
//                                 style: TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       InkWell(
//                         onTap: () {
//                           setState(() {
//                             livestreamController.seatCount.value = 9;
//                           });
//                         },
//                         child: Container(
//                           padding: EdgeInsets.symmetric(
//                               vertical: kHeight * 0.005,
//                               horizontal: kWeight * 0.02),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             color: livestreamController.seatCount.value == 9
//                                 ? Color(0xff6D59A1)
//                                 : Colors.black26,
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                             children: [
//                               Icon(
//                                 Icons.event_seat,
//                                 color: Colors.white,
//                                 size: kHeight * 0.015,
//                               ),
//                               const Text(
//                                 " 9",
//                                 style: TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 10),
//                       InkWell(
//                         onTap: () {
//                           setState(() {
//                             livestreamController.seatCount.value = 15;
//                           });
//                         },
//                         child: Container(
//                           padding: EdgeInsets.symmetric(
//                               vertical: kHeight * 0.005,
//                               horizontal: kWeight * 0.02),
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(10),
//                             color: livestreamController.seatCount.value == 15
//                                 ? Color(0xff6D59A1)
//                                 : Colors.black26,
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                             children: [
//                               Icon(
//                                 Icons.event_seat,
//                                 color: Colors.white,
//                                 size: kHeight * 0.015,
//                               ),
//                               const Text(
//                                 "15",
//                                 style: TextStyle(color: Colors.white),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: kHeight * 0.02),
//                   InkWell(
//                     onTap: () async {
//                       FocusScope.of(context).unfocus();
//
//                       // Get the stream title from the text field
//                       String streamTitle =
//                           _editingControllerStreamingTitle.text.trim();
//                       if (streamTitle.isEmpty) {
//                         streamTitle = _authController
//                             .userProfile.value.user!.name!; // Default title
//                       }
//
//                       print('Sagor test multi');
//
//                       // Create multi-live stream using the proper controller method
//                       await livestreamController.tryToCreateLivestream(
//                         streamTitle: streamTitle,
//                         streamType: 'multi',
//                         userId:
//                             _authController.userProfile.value.user!.id!.toInt(),
//                       );
//                     },
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Container(
//                           height: kHeight * 0.05,
//                           width: kWeight * 0.5,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(15),
//                             gradient: LinearGradient(
//                               colors: [
//                                 Color(0xff8A4CF7),
//                                 Color(0xffB460F0),
//                               ],
//                               begin: Alignment.topCenter,
//                               end: Alignment.bottomCenter,
//                             ),
//                           ),
//                           child: Center(
//                             child: Text(
//                               "Go LIVE",
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.bold,
//                                 fontSize: kHeight * 0.018,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: kHeight * 0.03),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
