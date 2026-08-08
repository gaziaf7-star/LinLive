import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

class AppmenuController extends GetxController {
  RxString familyName = ''.obs;
  RxString announcement = ''.obs;
  RxString pickedImage = ''.obs;
  RxString selectedCountry = ''.obs;

  bool get isFormValid =>
      familyName.isNotEmpty &&
      announcement.isNotEmpty &&
      pickedImage1.isNotEmpty &&
      selectedCountry.isNotEmpty;

  void singleFilePicker() async {
    // Pick image logic
    pickedImage.value = 'path/to/image'; // Update this after picking
  }

  final pickedImage1 = ''.obs; // single image file pick

  Future<void> singleFilePicker1() async {
    //file  ta k sudhu show korar jonno
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    pickedImage1.value = result!.files.single.path!; // Store paths
  }

  ///----------------------
}
