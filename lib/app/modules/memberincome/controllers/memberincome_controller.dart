import 'package:get/get.dart';

class MemberincomeController extends GetxController {
  RxBool isDropdownOpen = false.obs;

  RxInt tempDay = 1.obs;
  RxInt tempMonth = 1.obs;
  RxInt tempYear = DateTime.now().year.obs;

  List<int> get daysInMonth {
    int days = DateTime(tempYear.value, tempMonth.value + 1, 0).day;
    return List.generate(days, (i) => i + 1);
  }

  void toggleDropdown() {
    isDropdownOpen.value = !isDropdownOpen.value;
  }
}
