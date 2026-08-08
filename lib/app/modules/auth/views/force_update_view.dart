// import 'dart:io';
// import 'dart:ui';
//
//
// import 'package:app_installer/app_installer.dart';
// import 'package:archive/archive.dart';
// import 'package:dio/dio.dart';
// import 'package:dio/io.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:meetlivepro/app/modules/appmenu/views/widgets/vipcarddesign.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// import '../../../../constants/constants.dart';
// import '../../../../constants/name_constants.dart';
//
// class ForceUpdateView extends StatefulWidget {
//   const ForceUpdateView({super.key});
//
//   @override
//   State<ForceUpdateView> createState() => _ForceUpdateViewState();
// }
//
// class _ForceUpdateViewState extends State<ForceUpdateView> {
//   double progress = 0.0;
//   bool isDownloading = false;
//   bool isInstalling = false;
//   String statusMessage = 'Please update to continue using the app.';
//
//   Future<String?> _extractApkIfNeeded(String filePath) async {
//     final lower = filePath.toLowerCase();
//
//     if (!lower.endsWith('.zip')) {
//       return filePath;
//     }
//
//     try {
//       final bytes = await File(filePath).readAsBytes();
//       final archive = ZipDecoder().decodeBytes(bytes);
//       final dir = File(filePath).parent.path;
//
//       for (final f in archive) {
//         if (f.isFile && f.name.toLowerCase().endsWith('.apk')) {
//           final cleanName = f.name.split('/').last;
//           final out = File('$dir/$cleanName');
//
//           if (await out.exists()) {
//             await out.delete();
//           }
//
//           await out.create(recursive: true);
//           await out.writeAsBytes(f.content);
//
//           print('✅ APK extracted: ${out.path}');
//           print('✅ Extracted APK size: ${await out.length()} bytes');
//
//           return out.path;
//         }
//       }
//
//       print('❌ No APK found inside ZIP');
//       return null;
//     } catch (e) {
//       print('❌ Extraction error: $e');
//       return null;
//     }
//   }
//
//   Future<void> _startDownloadAndInstall() async {
//     if (isDownloading || isInstalling) return;
//
//     final url = authController.forceUpdateUrl.value.trim();
//
//     if (url.isEmpty) {
//       Get.snackbar(
//         'Update Failed',
//         'Download URL not found.',
//         backgroundColor: Colors.red,
//         colorText: Colors.white,
//         snackPosition: SnackPosition.BOTTOM,
//       );
//       return;
//     }
//
//     try {
//       final dir = await getTemporaryDirectory();
//
//       final latest = authController.serverVersion.value.trim().isEmpty
//           ? DateTime.now().millisecondsSinceEpoch.toString()
//           : authController.serverVersion.value.trim();
//
//       final isZip = url.toLowerCase().endsWith('.zip');
//       final ext = isZip ? 'zip' : 'apk';
//
//       final filePath = '${dir.path}/linlive_update_$latest.$ext';
//       final file = File(filePath);
//
//       // Important: আগের corrupt/cached APK থাকলে delete করবে
//       if (await file.exists()) {
//         await file.delete();
//         print('🗑️ Old update file deleted');
//       }
//
//       if (!mounted) return;
//
//       setState(() {
//         isDownloading = true;
//         isInstalling = false;
//         progress = 0.0;
//         statusMessage = 'Downloading…';
//       });
//
//       final dio = Dio(
//         BaseOptions(
//           connectTimeout: const Duration(seconds: 30),
//           receiveTimeout: const Duration(minutes: 10),
//           followRedirects: true,
//           validateStatus: (status) => status != null && status < 500,
//           responseType: ResponseType.bytes,
//           headers: {
//             'Accept': 'application/vnd.android.package-archive,*/*',
//             'User-Agent': 'LinLiveAppUpdater/1.0',
//           },
//         ),
//       );
//
//       dio.httpClientAdapter = IOHttpClientAdapter(
//         createHttpClient: () {
//           final client = HttpClient();
//
//           // SSL issue থাকলে download block না করার জন্য
//           client.badCertificateCallback = (cert, host, port) => true;
//
//           return client;
//         },
//       );
//
//       final response = await dio.download(
//         url,
//         filePath,
//         options: Options(
//           responseType: ResponseType.bytes,
//           followRedirects: true,
//           validateStatus: (status) => status != null && status < 500,
//           headers: {
//             'Accept': 'application/vnd.android.package-archive,*/*',
//             'User-Agent': 'LinLiveAppUpdater/1.0',
//           },
//         ),
//         onReceiveProgress: (received, total) {
//           if (total > 0 && mounted) {
//             setState(() {
//               progress = received / total;
//             });
//           }
//         },
//         deleteOnError: true,
//       );
//
//       final downloadedFile = File(filePath);
//
//       if (!await downloadedFile.exists()) {
//         throw 'Downloaded file not found';
//       }
//
//       final fileSize = await downloadedFile.length();
//
//       print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//       print('✅ Download URL: $url');
//       print('✅ Download status: ${response.statusCode}');
//       print('✅ Download path: $filePath');
//       print('✅ Download size: $fileSize bytes');
//       print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//
//       // APK file খুব ছোট হলে usually HTML/error page download হয়
//       if (fileSize < 1000000) {
//         final bytes = await downloadedFile.readAsBytes();
//         final previewBytes = bytes.take(300).toList();
//         final previewText = String.fromCharCodes(previewBytes);
//
//         print('❌ Invalid APK preview:');
//         print(previewText);
//
//         throw 'Invalid APK file. Server returned wrong file or incomplete download.';
//       }
//
//       await _proceedToInstall(filePath, isZip);
//     } catch (e) {
//       await _handleError(e, url);
//     }
//   }
//
//   Future<void> _proceedToInstall(String filePath, bool isZip) async {
//     try {
//       if (!mounted) return;
//
//       setState(() {
//         isDownloading = false;
//         isInstalling = true;
//         statusMessage = isZip ? 'Extracting…' : 'Opening Installer…';
//       });
//
//       String? apkPath = filePath;
//
//       if (isZip) {
//         apkPath = await _extractApkIfNeeded(filePath);
//       }
//
//       if (apkPath == null || !await File(apkPath).exists()) {
//         throw 'APK file not found after download';
//       }
//
//       final apkFile = File(apkPath);
//       final apkSize = await apkFile.length();
//
//       print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//       print('📦 Installing APK: $apkPath');
//       print('📦 APK size: $apkSize bytes');
//       print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//
//       if (apkSize < 1000000) {
//         throw 'APK file is too small or corrupted.';
//       }
//
//       if (!mounted) return;
//
//       setState(() {
//         statusMessage = 'Opening Installer…';
//       });
//
//       await AppInstaller.installApk(apkPath);
//
//       await Future.delayed(const Duration(seconds: 2));
//
//       if (!mounted) return;
//
//       setState(() {
//         isInstalling = false;
//         statusMessage = 'Installer opened. Please tap Install.';
//       });
//     } catch (e) {
//       await _handleError(e, authController.forceUpdateUrl.value.trim());
//     }
//   }
//
//   Future<void> _handleError(dynamic e, String url) async {
//     print('❌ Update error: $e');
//
//     if (mounted) {
//       setState(() {
//         isDownloading = false;
//         isInstalling = false;
//         statusMessage = 'Update failed. Try manual download.';
//       });
//     }
//
//     Get.snackbar(
//       'Update Failed',
//       e.toString(),
//       backgroundColor: Colors.red,
//       colorText: Colors.white,
//       snackPosition: SnackPosition.BOTTOM,
//       duration: const Duration(seconds: 4),
//     );
//
//     if (url.isNotEmpty) {
//       final u = Uri.parse(url);
//
//       if (await canLaunchUrl(u)) {
//         await launchUrl(
//           u,
//           mode: LaunchMode.externalApplication,
//         );
//       }
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final latest = authController.serverVersion.value;
//     final current = kAppVersion;
//
//     return WillPopScope(
//       onWillPop: () async => false,
//       child: Material(
//         color: Colors.black.withOpacity(0.5),
//         child: Stack(
//           children: [
//             Positioned.fill(
//               child: BackdropFilter(
//                 filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//                 child: Container(color: Colors.transparent),
//               ),
//             ),
//
//             Center(
//               child: Container(
//                 width: MediaQuery.of(context).size.width * 0.85,
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(4),
//                   gradient: LinearGradient(
//                     colors: [
//                       kAppColor2.withOpacity(.4),
//                       kAppColor1.withOpacity(.4),
//                     ],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   border: Border.all(color: Colors.white10),
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     _buildUpdateIcon(),
//
//                     const SizedBox(height: 20),
//
//                     const Text(
//                       'New Update Available',
//                       style: TextStyle(
//                         fontSize: 22,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//
//                     const SizedBox(height: 8),
//
//                     Text(
//                       'v$current → v$latest',
//                       style: TextStyle(
//                         fontSize: 16,
//                         color: kAppColor2,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//
//                     const SizedBox(height: 20),
//
//                     Text(
//                       statusMessage,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         color: Colors.white70,
//                       ),
//                     ),
//
//                     const SizedBox(height: 24),
//
//                     if (isDownloading) _buildProgressBar(),
//
//                     const SizedBox(height: 12),
//
//                     _buildActionButton(),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildUpdateIcon() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         shape: BoxShape.circle,
//         color: kAppColor2.withOpacity(0.2),
//       ),
//       child: const Icon(
//         Icons.system_update,
//         color: Colors.white,
//         size: 40,
//       ),
//     );
//   }
//
//   Widget _buildProgressBar() {
//     return Column(
//       children: [
//         ClipRRect(
//           borderRadius: BorderRadius.circular(10),
//           child: LinearProgressIndicator(
//             value: progress,
//             minHeight: 10,
//             backgroundColor: Colors.white10,
//             valueColor: AlwaysStoppedAnimation<Color>(kAppColor2),
//           ),
//         ),
//
//         const SizedBox(height: 8),
//
//         Text(
//           '${(progress * 100).toStringAsFixed(0)}%',
//           style: const TextStyle(
//             color: Colors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildActionButton() {
//     final bool isProcessing = isDownloading || isInstalling;
//
//     return InkWell(
//       onTap: isProcessing ? null : _startDownloadAndInstall,
//       borderRadius: BorderRadius.circular(16),
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 16),
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(16),
//           gradient: isProcessing
//               ? const LinearGradient(
//             colors: [
//               Color(0xfffb15d4),
//               Color(0xffbf4dfa),
//               Color(0xfffb1565),
//             ],
//           )
//               : LinearGradient(
//             colors: [
//               kAppColor2,
//               kAppColor1,
//             ],
//           ),
//         ),
//         child: Center(
//           child: Text(
//             isInstalling
//                 ? 'Installing...'
//                 : isDownloading
//                 ? 'Downloading...'
//                 : 'Update Now',
//             style: const TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }