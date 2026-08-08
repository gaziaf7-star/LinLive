import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app_translation_data.dart';

class AppLanguageOption {
  const AppLanguageOption({
    required this.key,
    required this.locale,
    required this.flag,
    required this.nativeName,
    required this.subtitle,
  });

  final String key;
  final Locale locale;
  final String flag;
  final String nativeName;
  final String subtitle;
}

/// Global application language controller.
///
/// The selected locale is stored locally and restored after app restart.
/// Arabic is RTL. Every other configured language is LTR.
class AppLanguageController extends GetxController {
  AppLanguageController({GetStorage? storage}) : _storage = storage ?? GetStorage();

  static const String _storageKey = 'app_locale_key';
  static AppLanguageController get to => Get.find<AppLanguageController>();

  static const List<AppLanguageOption> languageOptions = [
    AppLanguageOption(
      key: 'en',
      locale: Locale('en', 'US'),
      flag: '🇺🇸',
      nativeName: 'English',
      subtitle: 'English (United States)',
    ),
    AppLanguageOption(
      key: 'hi',
      locale: Locale('hi', 'IN'),
      flag: '🇮🇳',
      nativeName: 'हिन्दी',
      subtitle: 'हिन्दी (भारत)',
    ),
    AppLanguageOption(
      key: 'ta',
      locale: Locale('ta', 'IN'),
      flag: '🇮🇳',
      nativeName: 'தமிழ்',
      subtitle: 'தமிழ் (இந்தியா)',
    ),
    AppLanguageOption(
      key: 'ml',
      locale: Locale('ml', 'IN'),
      flag: '🇮🇳',
      nativeName: 'മലയാളം',
      subtitle: 'മലയാളം (ഇന്ത്യ)',
    ),
    AppLanguageOption(
      key: 'tr',
      locale: Locale('tr', 'TR'),
      flag: '🇹🇷',
      nativeName: 'Türkçe',
      subtitle: 'Türkçe (Türkiye)',
    ),
    AppLanguageOption(
      key: 'ne',
      locale: Locale('ne', 'NP'),
      flag: '🇳🇵',
      nativeName: 'नेपाली',
      subtitle: 'नेपाली (नेपाल)',
    ),
    AppLanguageOption(
      key: 'es',
      locale: Locale('es', 'ES'),
      flag: '🇪🇸',
      nativeName: 'Español',
      subtitle: 'Español (España)',
    ),
    AppLanguageOption(
      key: 'ru',
      locale: Locale('ru', 'RU'),
      flag: '🇷🇺',
      nativeName: 'Русский',
      subtitle: 'Русский (Россия)',
    ),
    AppLanguageOption(
      key: 'bn',
      locale: Locale('bn', 'BD'),
      flag: '🇧🇩',
      nativeName: 'বাংলা',
      subtitle: 'বাংলা (বাংলাদেশ)',
    ),
    AppLanguageOption(
      key: 'ja',
      locale: Locale('ja', 'JP'),
      flag: '🇯🇵',
      nativeName: '日本語',
      subtitle: '日本語 (日本)',
    ),
    AppLanguageOption(
      key: 'ko',
      locale: Locale('ko', 'KR'),
      flag: '🇰🇷',
      nativeName: '한국어',
      subtitle: '한국어 (대한민국)',
    ),
    AppLanguageOption(
      key: 'ar',
      locale: Locale('ar', 'SA'),
      flag: '🇸🇦',
      nativeName: 'العربية',
      subtitle: 'العربية (المملكة العربية السعودية)',
    ),
    AppLanguageOption(
      key: 'zh_TW',
      locale: Locale('zh', 'TW'),
      flag: '🇹🇼',
      nativeName: '繁體中文',
      subtitle: '繁體中文 (台灣)',
    ),
    AppLanguageOption(
      key: 'zh_CN',
      locale: Locale('zh', 'CN'),
      flag: '🇨🇳',
      nativeName: '简体中文',
      subtitle: '简体中文 (中国)',
    ),
  ];

  final GetStorage _storage;
  final Rx<Locale> currentLocale = const Locale('en', 'US').obs;
  final RxString currentLocaleKey = 'en'.obs;

  String get languageCode => currentLocale.value.languageCode;
  String get localeKey => currentLocaleKey.value;
  bool get isArabic => localeKey == 'ar';
  bool get isRtl => isArabic;

  AppLanguageOption get currentOption => languageOptions.firstWhere(
        (item) => item.key == localeKey,
    orElse: () => languageOptions.first,
  );

  String get currentLanguageName => currentOption.nativeName;
  String get currentLanguageSubtitle => currentOption.subtitle;

  Future<void> initialize() async {
    final String saved = (_storage.read<String>(_storageKey) ?? 'en').trim();
    final AppLanguageOption option = _optionFor(saved);
    currentLocaleKey.value = option.key;
    currentLocale.value = option.locale;
  }

  Future<void> changeLanguage(String key) async {
    final AppLanguageOption option = _optionFor(key);
    currentLocaleKey.value = option.key;
    currentLocale.value = option.locale;
    await _storage.write(_storageKey, option.key);
    Get.updateLocale(option.locale);
  }

  AppLanguageOption _optionFor(String key) {
    final String normalized = key.trim();
    for (final AppLanguageOption item in languageOptions) {
      if (item.key == normalized) return item;
    }
    return languageOptions.first;
  }
}

extension AppLocalizedString on String {
  /// Localizes only user-visible text that has been explicitly connected
  /// with `.appTr`. API keys, routes, socket events and asset paths remain raw.
  String get appTr => AppLocalizer.translate(this);
}

class AppLocalizer {
  AppLocalizer._();

  static final Map<String, List<MapEntry<String, String>>> _sortedExactCache = {};
  static final Map<String, List<MapEntry<String, String>>> _sortedWordCache = {};

  static String translate(String input) {
    if (input.isEmpty) return input;

    final String code = _activeCode();
    if (code == 'en') return input;
    if (_mustStayUnchanged(input)) return input;

    final String trimmed = input.trim();
    final Map<String, String> exactMap = kAppExactTranslations[code] ?? const {};
    final String? exact = exactMap[trimmed] ??
        kAppSupplementalTranslations[code]?[trimmed] ??
        kAppInviteTranslations[code]?[trimmed];
    if (exact != null) return _restoreOuterWhitespace(input, exact);

    final String templated = _translateTemplates(trimmed, code);
    if (templated != trimmed) {
      return _restoreOuterWhitespace(input, templated);
    }

    final String translated = _translateKnownPhrases(trimmed, code);
    return _restoreOuterWhitespace(input, translated);
  }

  static String _activeCode() {
    if (Get.isRegistered<AppLanguageController>()) {
      return AppLanguageController.to.localeKey;
    }

    final Locale? locale = Get.locale;
    if (locale == null) return 'en';
    if (locale.languageCode == 'zh') {
      return locale.countryCode?.toUpperCase() == 'TW' ? 'zh_TW' : 'zh_CN';
    }
    return locale.languageCode;
  }

  static String coinsText(int coins) {
    final String label = coins == 1 ? 'Coin'.appTr : 'Coins'.appTr;
    return '$coins $label';
  }

  static String friendIdText(dynamic id) {
    final String label = 'Friend ID'.appTr;
    return '$label: $id';
  }

  static String inviteFriendsRemaining(
      int count, {
        bool toUnlock = false,
      }) {
    final String code = _activeCode();

    switch (code) {
      case 'hi':
        return toUnlock
            ? 'इस VIP इनाम को अनलॉक करने के लिए $count मित्र बाकी हैं।'
            : '$count मित्र बाकी हैं';
      case 'ta':
        return toUnlock
            ? 'இந்த VIP வெகுமதியைத் திறக்க இன்னும் $count நண்பர்கள் தேவை.'
            : 'இன்னும் $count நண்பர்கள் மீதம்';
      case 'ml':
        return toUnlock
            ? 'ഈ VIP റിവാർഡ് അൺലോക്ക് ചെയ്യാൻ ഇനി $count സുഹൃത്തുകൾ വേണം.'
            : '$count സുഹൃത്തുകൾ കൂടി ബാക്കി';
      case 'tr':
        return toUnlock
            ? 'Bu VIP ödülünü açmak için $count arkadaş kaldı.'
            : '$count arkadaş kaldı';
      case 'ne':
        return toUnlock
            ? 'यो VIP पुरस्कार अनलक गर्न अझै $count साथी बाँकी छन्।'
            : '$count साथी बाँकी छन्';
      case 'es':
        return toUnlock
            ? 'Faltan $count amigos para desbloquear esta recompensa VIP.'
            : 'Faltan $count amigos';
      case 'ru':
        return toUnlock
            ? 'Осталось $count друзей, чтобы открыть эту VIP-награду.'
            : 'Осталось друзей: $count';
      case 'bn':
        return toUnlock
            ? 'এই VIP পুরস্কার আনলক করতে আরও $count জন বন্ধু প্রয়োজন।'
            : 'আরও $count জন বন্ধু বাকি';
      case 'ja':
        return toUnlock
            ? 'このVIP報酬の解除まであと$count人です。'
            : 'あと$count人';
      case 'ko':
        return toUnlock
            ? '이 VIP 보상을 잠금 해제하려면 친구 $count명이 더 필요합니다.'
            : '친구 $count명 남음';
      case 'ar':
        return toUnlock
            ? 'يتبقى $count من الأصدقاء لفتح مكافأة VIP هذه.'
            : 'يتبقى $count من الأصدقاء';
      case 'zh_TW':
        return toUnlock
            ? '還需 $count 位好友即可解鎖此 VIP 獎勵。'
            : '還剩 $count 位好友';
      case 'zh_CN':
        return toUnlock
            ? '还需 $count 位好友即可解锁此 VIP 奖励。'
            : '还剩 $count 位好友';
      default:
        return toUnlock
            ? '$count friends remaining to unlock this VIP reward.'
            : '$count friends remaining';
    }
  }

  static bool _mustStayUnchanged(String value) {
    final String text = value.trim();
    if (text.isEmpty) return true;
    if (RegExp(r'^https?://', caseSensitive: false).hasMatch(text)) return true;
    if (RegExp(r'^www\.', caseSensitive: false).hasMatch(text)) return true;
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) return true;
    if (RegExp(r'^(assets?|images?)/', caseSensitive: false).hasMatch(text)) {
      return true;
    }
    if (RegExp(r'^[\d\s+\-–—.,:%/\\|()\[\]{}<>#@*•→←↑↓💎🪙🧧🎁❤️👍❧༺༒☬✦]+$')
        .hasMatch(text)) {
      return true;
    }
    return false;
  }

  static String _restoreOuterWhitespace(String original, String translated) {
    final String leading = RegExp(r'^\s*').firstMatch(original)?.group(0) ?? '';
    final String trailing = RegExp(r'\s*$').firstMatch(original)?.group(0) ?? '';
    return '$leading$translated$trailing';
  }

  static String _exactLabel(String english, String code) {
    return kAppExactTranslations[code]?[english] ?? english;
  }

  static String _translateTemplates(String value, String code) {
    Match? match;

    match = RegExp(r'^ID\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_idLabel(code)}: ${match.group(1)}';

    match = RegExp(r'^UID\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_uidLabel(code)}: ${match.group(1)}';

    match = RegExp(r'^Level\s*:?\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_exactLabel('Level', code)}: ${match.group(1)}';

    match = RegExp(r'^Lv\.?\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_exactLabel('Level', code)} ${match.group(1)}';

    match = RegExp(r'^Phone\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_exactLabel('Phone', code)}: ${match.group(1)}';

    match = RegExp(r'^Name\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_exactLabel('Name', code)}: ${match.group(1)}';

    match = RegExp(r'^Status\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_statusLabel(code)}: ${match.group(1)}';

    match = RegExp(r'^Price\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_priceLabel(code)}: ${match.group(1)}';

    match = RegExp(r'^Amount\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_exactLabel('Amount', code)}: ${match.group(1)}';

    match = RegExp(r'^Current\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_currentLabel(code)}: ${match.group(1)}';

    match = RegExp(r'^From\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_fromLabel(code)}: ${match.group(1)}';

    match = RegExp(r'^Room\s+(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_roomLabel(code)} ${match.group(1)}';

    match = RegExp(r'^Layout\s+(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_layoutLabel(code)} ${match.group(1)}';

    match = RegExp(r'^(.+)\s+Days$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${match.group(1)} ${_exactLabel('Days', code)}';

    match = RegExp(r'^(.+)\s+Coins$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${match.group(1)} ${_exactLabel('Coins', code)}';

    match = RegExp(r'^No\s+(.+)\s+found$', caseSensitive: false).firstMatch(value);
    if (match != null) return _noFound(match.group(1) ?? '', code);

    match = RegExp(r'^Search\s+by\s+(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return _searchBy(match.group(1) ?? '', code);

    match = RegExp(r'^Error\s*:\s*(.+)$', caseSensitive: false).firstMatch(value);
    if (match != null) return '${_errorLabel(code)}: ${match.group(1)}';

    return value;
  }

  static String _translateKnownPhrases(String value, String code) {
    String result = value;

    final List<MapEntry<String, String>> exactEntries =
    _sortedExactCache.putIfAbsent(code, () {
      final Map<String, String> merged = <String, String>{
        ...?kAppExactTranslations[code],
        ...?kAppSupplementalTranslations[code],
        ...?kAppInviteTranslations[code],
      };
      final List<MapEntry<String, String>> entries = merged.entries
          .where((entry) => entry.key.isNotEmpty && entry.key != entry.value)
          .toList();
      entries.sort((a, b) => b.key.length.compareTo(a.key.length));
      return entries;
    });

    result = _replaceEntries(result, exactEntries);

    final List<MapEntry<String, String>> wordEntries =
    _sortedWordCache.putIfAbsent(code, () {
      final Map<String, String> mergedWords = <String, String>{
        ...?kAppExtraWordTranslations[code],
        ...?kAppInviteWordTranslations[code],
      };
      final List<MapEntry<String, String>> entries = mergedWords.entries
          .where((entry) => entry.key.isNotEmpty && entry.key != entry.value)
          .toList();
      entries.sort((a, b) => b.key.length.compareTo(a.key.length));
      return entries;
    });

    return _replaceEntries(result, wordEntries);
  }

  static String _replaceEntries(
      String input,
      List<MapEntry<String, String>> entries,
      ) {
    String result = input;
    for (final MapEntry<String, String> entry in entries) {
      final RegExp pattern = RegExp(
        r'(^|[^A-Za-z])(' + RegExp.escape(entry.key) + r')(?=$|[^A-Za-z])',
        caseSensitive: false,
      );
      result = result.replaceAllMapped(
        pattern,
            (Match match) => '${match.group(1) ?? ''}${entry.value}',
      );
    }
    return result;
  }

  static String _noFound(String item, String code) {
    switch (code) {
      case 'hi':
        return 'कोई $item नहीं मिला';
      case 'ta':
        return '$item கிடைக்கவில்லை';
      case 'ml':
        return '$item കണ്ടെത്തിയില്ല';
      case 'tr':
        return '$item bulunamadı';
      case 'ne':
        return 'कुनै $item भेटिएन';
      case 'es':
        return 'No se encontró $item';
      case 'ru':
        return '$item не найдено';
      case 'bn':
        return 'কোনো $item পাওয়া যায়নি';
      case 'ja':
        return '$itemが見つかりません';
      case 'ko':
        return '$item을(를) 찾을 수 없습니다';
      case 'ar':
        return 'لم يتم العثور على $item';
      case 'zh_TW':
        return '找不到$item';
      case 'zh_CN':
        return '未找到$item';
      default:
        return 'No $item found';
    }
  }

  static String _searchBy(String item, String code) {
    switch (code) {
      case 'hi':
        return '$item से खोजें';
      case 'ta':
        return '$item மூலம் தேடவும்';
      case 'ml':
        return '$item ഉപയോഗിച്ച് തിരയുക';
      case 'tr':
        return '$item ile ara';
      case 'ne':
        return '$item बाट खोज्नुहोस्';
      case 'es':
        return 'Buscar por $item';
      case 'ru':
        return 'Поиск по $item';
      case 'bn':
        return '$item দিয়ে খুঁজুন';
      case 'ja':
        return '$itemで検索';
      case 'ko':
        return '$item로 검색';
      case 'ar':
        return 'البحث بواسطة $item';
      case 'zh_TW':
        return '依$item搜尋';
      case 'zh_CN':
        return '按$item搜索';
      default:
        return 'Search by $item';
    }
  }

  static String _idLabel(String code) => code == 'ar' ? 'المعرّف' : 'ID';
  static String _uidLabel(String code) => code == 'ar' ? 'معرّف المستخدم' : 'UID';
  static String _statusLabel(String code) => _localizedSmallLabel(code, 'Status');
  static String _priceLabel(String code) => _localizedSmallLabel(code, 'Price');
  static String _currentLabel(String code) => _localizedSmallLabel(code, 'Current');
  static String _fromLabel(String code) => _localizedSmallLabel(code, 'From');
  static String _roomLabel(String code) => _localizedSmallLabel(code, 'Room');
  static String _layoutLabel(String code) => _localizedSmallLabel(code, 'Layout');
  static String _errorLabel(String code) => _localizedSmallLabel(code, 'Error');

  static String _localizedSmallLabel(String code, String english) {
    const Map<String, Map<String, String>> labels = {
      'hi': {
        'Status': 'स्थिति', 'Price': 'मूल्य', 'Current': 'वर्तमान',
        'From': 'से', 'Room': 'रूम', 'Layout': 'लेआउट', 'Error': 'त्रुटि',
      },
      'ta': {
        'Status': 'நிலை', 'Price': 'விலை', 'Current': 'தற்போதைய',
        'From': 'இருந்து', 'Room': 'அறை', 'Layout': 'அமைப்பு', 'Error': 'பிழை',
      },
      'ml': {
        'Status': 'നില', 'Price': 'വില', 'Current': 'നിലവിലെ',
        'From': 'നിന്ന്', 'Room': 'റൂം', 'Layout': 'ലേഔട്ട്', 'Error': 'പിശക്',
      },
      'tr': {
        'Status': 'Durum', 'Price': 'Fiyat', 'Current': 'Mevcut',
        'From': 'Kimden', 'Room': 'Oda', 'Layout': 'Düzen', 'Error': 'Hata',
      },
      'ne': {
        'Status': 'स्थिति', 'Price': 'मूल्य', 'Current': 'हालको',
        'From': 'बाट', 'Room': 'रुम', 'Layout': 'लेआउट', 'Error': 'त्रुटि',
      },
      'es': {
        'Status': 'Estado', 'Price': 'Precio', 'Current': 'Actual',
        'From': 'De', 'Room': 'Sala', 'Layout': 'Diseño', 'Error': 'Error',
      },
      'ru': {
        'Status': 'Статус', 'Price': 'Цена', 'Current': 'Текущий',
        'From': 'От', 'Room': 'Комната', 'Layout': 'Макет', 'Error': 'Ошибка',
      },
      'bn': {
        'Status': 'স্ট্যাটাস', 'Price': 'মূল্য', 'Current': 'বর্তমান',
        'From': 'থেকে', 'Room': 'রুম', 'Layout': 'লেআউট', 'Error': 'ত্রুটি',
      },
      'ja': {
        'Status': 'ステータス', 'Price': '価格', 'Current': '現在',
        'From': '送信元', 'Room': 'ルーム', 'Layout': 'レイアウト', 'Error': 'エラー',
      },
      'ko': {
        'Status': '상태', 'Price': '가격', 'Current': '현재',
        'From': '보낸 사람', 'Room': '룸', 'Layout': '레이아웃', 'Error': '오류',
      },
      'ar': {
        'Status': 'الحالة', 'Price': 'السعر', 'Current': 'الحالي',
        'From': 'من', 'Room': 'الغرفة', 'Layout': 'التخطيط', 'Error': 'خطأ',
      },
      'zh_TW': {
        'Status': '狀態', 'Price': '價格', 'Current': '目前',
        'From': '來自', 'Room': '房間', 'Layout': '版面', 'Error': '錯誤',
      },
      'zh_CN': {
        'Status': '状态', 'Price': '价格', 'Current': '当前',
        'From': '来自', 'Room': '房间', 'Layout': '布局', 'Error': '错误',
      },
    };
    return labels[code]?[english] ?? english;
  }
}
