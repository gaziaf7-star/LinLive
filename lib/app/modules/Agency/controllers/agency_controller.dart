import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';

class AgencyController extends GetxController {
  final dio = Dio();

  final nickNameController = TextEditingController();
  final idController = ''.obs;
  final emailController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final blanceController = ''.obs;
  final coinController = ''.obs;
  final giftCoinController = ''.obs;
  final addressController = TextEditingController();
  final profile_imageController = ''.obs;
  final coverImageController = ''.obs;
  final agencyData = {}.obs;



  // single pick file

  final pickedImage = ''.obs; // Store file path as String

  Future<void> singleFilePicker() async {
    //file  ta k sudhu show korar jonno
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    pickedImage.value = result!.files.single.path!; // Store paths
  }
}
