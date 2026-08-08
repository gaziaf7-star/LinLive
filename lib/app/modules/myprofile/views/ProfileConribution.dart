import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/color_constants.dart';
import '../../../../constants/constants.dart';
import '../../../../constants/layout_constant.dart';
import 'profile_contributionList.dart';

import 'package:meetlivepro/app/localization/app_localizer.dart';
class Profileconribution extends StatefulWidget {
  const Profileconribution({super.key});

  @override
  State<Profileconribution> createState() => _ProfileconributionState();
}

class _ProfileconributionState extends State<Profileconribution> {
  bool isMonthlyTab = false;
  String selectedFilterKey = 'monthly';
  late final String userId;

  @override
  void initState() {
    super.initState();

    final args = Get.arguments;
    if (args is Map && args['userId'] != null) {
      userId = args['userId'].toString();
    } else if (args != null) {
      userId = args.toString();
    } else {
      userId = '${authController.userProfile.value.user?.id ?? ''}';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchList();
    });
  }

  Future<void> _fetchList() async {
    final key = isMonthlyTab ? selectedFilterKey : 'all';
    await myprofileController.showProfileContributionList(
      userId: userId,
      key: key,
    );
  }

  void _switchTab(bool monthly) {
    if (isMonthlyTab == monthly) return;
    setState(() {
      isMonthlyTab = monthly;
      if (!isMonthlyTab) {
        selectedFilterKey = 'monthly';
      }
    });
    _fetchList();
  }

  void _changeFilter(String key) {
    if (selectedFilterKey == key) return;
    setState(() {
      selectedFilterKey = key;
    });
    _fetchList();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFF),
      body: Stack(
        children: [
          Container(
            height: h * 0.265,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  kAppColor1,
                  kAppColor2,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: w * 0.045,
                    vertical: h * 0.008,
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: Get.back,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          height: w * 0.10,
                          width: w * 0.10,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            ('Ranking').appTr,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: w * 0.056,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: w * 0.10),
                    ],
                  ),
                ),
                SizedBox(height: h * 0.012),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.07),
                  child: Row(
                    children: [
                      Expanded(
                        child: _topTabButton(
                          title: ('Overall Ranking').appTr,
                          selected: !isMonthlyTab,
                          onTap: () => _switchTab(false),
                        ),
                      ),
                      Expanded(
                        child: _topTabButton(
                          title: ('Monthly Ranking').appTr,
                          selected: isMonthlyTab,
                          onTap: () => _switchTab(true),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  height: isMonthlyTab ? h * 0.08 : h * 0.018,
                  child: isMonthlyTab
                      ? Padding(
                    padding: EdgeInsets.fromLTRB(
                      w * 0.05,
                      h * 0.014,
                      w * 0.05,
                      0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _filterDropdownLike(),
                        ),
                        SizedBox(width: w * 0.04),
                        _countDownBox(label: '30'),
                        _colon(),
                        _countDownBox(label: '08'),
                        _colon(),
                        _countDownBox(label: '24'),
                        _colon(),
                        _countDownBox(label: '30'),
                      ],
                    ),
                  )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xffF8FAFF),
                    ),
                    child: ProfileContributionList(
                      isMonthlyMode: isMonthlyTab,
                      filterKey: selectedFilterKey,
                      onRefresh: _fetchList,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topTabButton({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final w = MediaQuery.of(context).size.width;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: w * 0.11,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                color: selected
                    ? Colors.white
                    : Colors.white.withOpacity(0.58),
                fontSize: w * 0.042,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            SizedBox(height: w * 0.006),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Container(
                width: w * 0.052,
                height: w * 0.010,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdownLike() {
    final options = <String, String>{
      'daily': ('Daily').appTr,
      'weekly': ('Weekly').appTr,
      'monthly': ('Monthly').appTr,
      'all': ('All').appTr,
    };

    return PopupMenuButton<String>(
      onSelected: _changeFilter,
      color: kAppColor2,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      itemBuilder: (context) => options.entries
          .map(
            (e) => PopupMenuItem<String>(
          value: e.key,
          child: Text(
            e.value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      )
          .toList(),
      child: Container(
        height: kHeight * 0.042,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                color: Colors.white.withOpacity(.90), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _filterTitle(selectedFilterKey),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded,
                color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }

  String _filterTitle(String key) {
    switch (key) {
      case 'daily':
        return 'Today';
      case 'weekly':
        return 'This Week';
      case 'monthly':
        return 'This Month';
      case 'all':
        return 'All Time';
      default:
        return 'This Month';
    }
  }

  Widget _countDownBox({required String label}) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _colon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        ':',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
