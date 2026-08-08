import 'package:country_picker/country_picker.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../../apis/api_endpoints.dart';
import '../../../../constants/constants.dart';

class RankingController extends GetxController {
  var selectedCountry = Rx<Country>(
    Country(
      countryCode: 'BD',
      phoneCode: '880',
      e164Sc: 0,
      geographic: true,
      level: 1,
      name: 'Bangladesh',
      example: '',
      displayName: 'Bangladesh',
      displayNameNoCountryCode: 'Bangladesh',
      e164Key: '',
    ),
  );

  final isFollow = false.obs;
  final isLoading = false.obs;
  final selectedRankingPeriod = 'daily'.obs;

  /// Main ranking tab: 0 = Sending, 1 = Receiving, 2 = Agency.
  final selectedMainRankingTab = 0.obs;

  final Dio _dio = Dio();

  final rankingList = [].obs;

  @override
  void onInit() {
    super.onInit();
    // First data load automatically. This fixes the issue where list shows only after pull refresh.
    Future.microtask(() => showRankingList(period: selectedRankingPeriod.value, force: false));
  }

  void setMainRankingTab(int index) {
    selectedMainRankingTab.value = index < 0 ? 0 : (index > 2 ? 2 : index);
  }

  Future getRankingList() async {
    try {
      final data = await _dio.get(kRankingUrl);
      rankingList.value = data.data is List ? data.data : [];
    } catch (e) {
      print('getRankingList error: $e');
      rankingList.clear();
    }
  }

  /// ------------------------- Ranking List show -------------------
  /// Old public lists are kept so your previous UI pages do not break.
  final senderRanking = [].obs;
  final receiverRanking = [].obs;
  final agencyRanking = [].obs;

  /// New period based cache.
  final dailySenderRanking = [].obs;
  final weeklySenderRanking = [].obs;
  final monthlySenderRanking = [].obs;
  final overallSenderRanking = [].obs;

  final dailyReceiverRanking = [].obs;
  final weeklyReceiverRanking = [].obs;
  final monthlyReceiverRanking = [].obs;
  final overallReceiverRanking = [].obs;

  final dailyAgencyRanking = [].obs;
  final weeklyAgencyRanking = [].obs;
  final monthlyAgencyRanking = [].obs;
  final overallAgencyRanking = [].obs;

  final Set<String> _loadedPeriods = <String>{};

  String _normalizePeriod(String period) {
    final p = period.trim().toLowerCase().replaceAll(' ', '_');
    if (p == 'week') return 'weekly';
    if (p == 'month') return 'monthly';
    if (p == 'all' || p == 'overall' || p == 'over_all') return 'overall';
    if (p == 'daily' || p == 'weekly' || p == 'monthly') return p;
    return 'daily';
  }

  Future showRankingList({String period = 'daily', bool force = false}) async {
    final String fixedPeriod = _normalizePeriod(period);
    selectedRankingPeriod.value = fixedPeriod;

    if (!force && _loadedPeriods.contains(fixedPeriod)) {
      _syncOldLists(fixedPeriod);
      return;
    }

    try {
      isLoading.value = true;

      final response = await _dio.get(
        kRankingList,
        queryParameters: {
          // Backend যেটা support করে সেটা use হবে।
          // যদি backend এখনো period filter support না করে,
          // তাহলেও old response থেকে sender/receiver/agency safe ভাবে load হবে।
          'period': fixedPeriod,
          'type': fixedPeriod,
          'range': fixedPeriod,
          'country': selectedCountry.value.name,
          'country_code': selectedCountry.value.countryCode,
        },
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${authController.userProfile.value.token}',
          },
        ),
      );

      if (response.statusCode == 200 && response.data is Map) {
        final Map data = response.data as Map;

        final List sender = _extractPeriodList(data, 'sender', fixedPeriod);
        final List receiver = _extractPeriodList(data, 'receiver', fixedPeriod);
        final List agency = _extractPeriodList(data, 'agency', fixedPeriod);

        _setPeriodLists(
          period: fixedPeriod,
          sender: sender,
          receiver: receiver,
          agency: agency,
        );

        _loadedPeriods.add(fixedPeriod);
        _syncOldLists(fixedPeriod);
      }
    } catch (e) {
      print('showRankingList error [$fixedPeriod]: $e');
      _setPeriodLists(period: fixedPeriod, sender: [], receiver: [], agency: []);
      _syncOldLists(fixedPeriod);
    } finally {
      isLoading.value = false;
    }
  }

  Future refreshRankingPeriod(String period) async {
    final fixedPeriod = _normalizePeriod(period);
    _loadedPeriods.remove(fixedPeriod);
    await showRankingList(period: fixedPeriod, force: true);
  }

  List<dynamic> senderRankingFor(String period) {
    switch (_normalizePeriod(period)) {
      case 'weekly':
        return weeklySenderRanking;
      case 'monthly':
        return monthlySenderRanking;
      case 'overall':
        return overallSenderRanking;
      case 'daily':
      default:
        return dailySenderRanking;
    }
  }

  List<dynamic> receiverRankingFor(String period) {
    switch (_normalizePeriod(period)) {
      case 'weekly':
        return weeklyReceiverRanking;
      case 'monthly':
        return monthlyReceiverRanking;
      case 'overall':
        return overallReceiverRanking;
      case 'daily':
      default:
        return dailyReceiverRanking;
    }
  }

  List<dynamic> agencyRankingFor(String period) {
    switch (_normalizePeriod(period)) {
      case 'weekly':
        return weeklyAgencyRanking;
      case 'monthly':
        return monthlyAgencyRanking;
      case 'overall':
        return overallAgencyRanking;
      case 'daily':
      default:
        return dailyAgencyRanking;
    }
  }

  List _extractPeriodList(Map data, String key, String period) {
    final List<String> directKeys = [
      '${period}_$key',
      '${key}_$period',
      period == 'overall' ? '${key}_overall' : '',
      period == 'overall' ? '${key}_all' : '',
      period == 'overall' ? 'all_$key' : '',
    ].where((e) => e.isNotEmpty).toList();

    for (final itemKey in directKeys) {
      final value = data[itemKey];
      if (value is List) return value;
      if (value is Map && value['data'] is List) return value['data'];
    }

    final periodBox = data[period];
    if (periodBox is Map) {
      final value = periodBox[key];
      if (value is List) return value;
      if (value is Map && value['data'] is List) return value['data'];
    }

    final box = data[key];
    if (box is List) return box;
    if (box is Map) {
      final periodList = box[period];
      if (periodList is List) return periodList;
      if (period == 'overall') {
        final allList = box['all'] ?? box['over_all'] ?? box['overall'];
        if (allList is List) return allList;
      }
      if (box['data'] is List) return box['data'];
    }

    return [];
  }

  void _setPeriodLists({
    required String period,
    required List sender,
    required List receiver,
    required List agency,
  }) {
    switch (_normalizePeriod(period)) {
      case 'weekly':
        weeklySenderRanking.value = sender;
        weeklyReceiverRanking.value = receiver;
        weeklyAgencyRanking.value = agency;
        break;
      case 'monthly':
        monthlySenderRanking.value = sender;
        monthlyReceiverRanking.value = receiver;
        monthlyAgencyRanking.value = agency;
        break;
      case 'overall':
        overallSenderRanking.value = sender;
        overallReceiverRanking.value = receiver;
        overallAgencyRanking.value = agency;
        break;
      case 'daily':
      default:
        dailySenderRanking.value = sender;
        dailyReceiverRanking.value = receiver;
        dailyAgencyRanking.value = agency;
        break;
    }
  }

  void _syncOldLists(String period) {
    senderRanking.value = List.from(senderRankingFor(period));
    receiverRanking.value = List.from(receiverRankingFor(period));
    agencyRanking.value = List.from(agencyRankingFor(period));
  }

  /// ---------------- top pk host ranking list ------------------------
  final dalyRanking = [].obs;
  final weeklyRanking = [].obs;
  final monthlyRanking = [].obs;

  Future showTopPkHost() async {
    try {
      final response = await _dio.get(kTopPkHostList);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        print('topPk host data ${response.data}');
        dalyRanking.value = data['daily'] ?? [];
        weeklyRanking.value = data['weekly'] ?? [];
        monthlyRanking.value = data['monthly'] ?? [];
      }
    } catch (e) {
      print('showTopPkHost error: $e');
    }
  }

  /// ----------------- top Hourly Pk Ranking ---------
  final hourlyRankingList = [].obs;

  Future showTopHourly() async {
    try {
      final response = await _dio.get(kTopPkHourlyList);

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map;
        print('topPk host data ${response.data}');
        hourlyRankingList.value = data['daily'] ?? [];
      }
    } catch (e) {
      print('showTopHourly error: $e');
    }
  }
}
