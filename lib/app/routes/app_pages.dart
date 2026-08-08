import 'package:get/get.dart';

import '../modules/Agency/bindings/agency_binding.dart';
import '../modules/Agency/views/agency_view.dart';
import '../modules/Cp/bindings/cp_binding.dart';
import '../modules/Cp/views/cp_view.dart';
import '../modules/accountInfornation/bindings/account_infornation_binding.dart';
import '../modules/accountInfornation/views/account_infornation_view.dart';
import '../modules/appmenu/bindings/appmenu_binding.dart';
import '../modules/appmenu/views/appmenu_view.dart';
import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/auth_view.dart';
import '../modules/auth/views/profile_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/informationcollection/bindings/informationcollection_binding.dart';
import '../modules/informationcollection/views/informationcollection_view.dart';

import '../modules/memberincome/bindings/memberincome_binding.dart';
import '../modules/memberincome/views/memberincome_view.dart';
import '../modules/messanger/bindings/messanger_binding.dart';
import '../modules/messanger/views/messanger_view.dart';

import '../modules/moments/bindings/moments_binding.dart';
import '../modules/moments/views/moments_view.dart';
import '../modules/myprofile/bindings/myprofile_binding.dart';
import '../modules/notification/bindings/notification_binding.dart';
import '../modules/notification/views/notification_view.dart';
import '../modules/ranking/bindings/ranking_binding.dart';
import '../modules/ranking/views/ranking_view.dart';
import '../modules/rechage/bindings/rechage_binding.dart';
import '../modules/rechage/views/rechage_view.dart';
import '../modules/record/bindings/record_binding.dart';
import '../modules/record/views/record_view.dart';
import '../modules/reseller/bindings/reseller_binding.dart';
import '../modules/reseller/views/reseller_view.dart';
import '../modules/setting/bindings/setting_binding.dart';
import '../modules/setting/views/setting_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import '../modules/trading/bindings/trading_binding.dart';
import '../modules/trading/views/trading_view.dart';
import '../modules/verified/bindings/verified_binding.dart';
import '../modules/verified/views/verified_view.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: _Paths.HOME,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: _Paths.AUTH,
      page: () => const AuthView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: _Paths.MESSANGER,
      page: () => MessengerView(),
      binding: MessangerBinding(),
    ),
    GetPage(
      name: _Paths.RANKING,
      page: () => const RankingView(),
      binding: RankingBinding(),
    ),
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: _Paths.MOMENTS,
      page: () => MomentsView(),
      binding: MomentsBinding(),
    ),

    GetPage(
      name: _Paths.APPMENU,
      page: () => const AppmenuView(),
      binding: AppmenuBinding(),
    ),
    GetPage(
      name: _Paths.SETTING,
      page: () => const SettingView(),
      binding: SettingBinding(),
    ),
    GetPage(
      name: _Paths.MYPROFILE,
      page: () => const ProfileView(),
      binding: MyprofileBinding(),
    ),
    GetPage(
      name: _Paths.MEMBERINCOME,
      page: () => MemberincomeView(),
      binding: MemberincomeBinding(),
    ),
    GetPage(
      name: _Paths.INFORMATIONCOLLECTION,
      page: () => const InformationcollectionView(),
      binding: InformationcollectionBinding(),
    ),
    GetPage(
      name: _Paths.AGENCY,
      page: () => const AgencyView(),
      binding: AgencyBinding(),
    ),
    GetPage(
      name: _Paths.ACCOUNT_INFORNATION,
      page: () => const AccountInformationView(),
      binding: AccountInfornationBinding(),
    ),
    GetPage(
      name: _Paths.RECORD,
      page: () => const RecordView(),
      binding: RecordBinding(),
    ),
    GetPage(
      name: _Paths.RECHAGE,
      page: () => const RechageView(),
      binding: RechageBinding(),
    ),
    GetPage(
      name: _Paths.VERIFIED,
      page: () => const VerifiedView(),
      binding: VerifiedBinding(),
    ),
    GetPage(
      name: _Paths.NOTIFICATION,
      page: () => const NotificationView(),
      binding: NotificationBinding(),
    ),
    GetPage(
      name: _Paths.TRADING,
      page: () => const TradingView(),
      binding: TradingBinding(),
    ),
    GetPage(
      name: _Paths.RESELLER,
      page: () => ResellerView(),
      binding: ResellerBinding(),
    ),
    GetPage(
      name: _Paths.CP,
      page: () => const CpHomePage(),
      binding: CpBinding(),
    ),
  ];
}
