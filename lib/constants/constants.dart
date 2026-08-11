import 'package:get/get.dart';

import '../app/modules/auth/controllers/auth_controller.dart';
import '../app/modules/home/controllers/home_controller.dart';
import '../app/modules/informationcollection/controllers/informationcollection_controller.dart';
import '../app/modules/livestream/controllers/livestream_controller.dart';
import '../app/modules/livestream/socket/websocket_controller.dart';
import '../app/modules/moments/controllers/moments_controller.dart';
import '../app/modules/myprofile/controllers/myprofile_controller.dart';
import '../app/modules/registersteps/controllers/registersteps_controller.dart';
import '../app/modules/store/controllers/store1_controller.dart';
import '../app/modules/verified/controllers/verified_controller.dart';

AuthController authController = Get.find();
RegisterstepsController registerstepsController = Get.find();
LivestreamController livestreamController = Get.find();
WebsocketController websocketController = Get.find();
HomeController homeController = Get.find();
MomentsController momentsController = Get.find();
Store1Controller store1controller = Get.find();
MyprofileController myprofileController = Get.find();
VerifiedController verifiedController = Get.find();
InformationcollectionController informationcollectionController = Get.find();

const String appId = "4d68656dc95447fc97b709a5321482bd"; // Your Agora App ID
