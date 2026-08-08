import '../../../../apis/api_endpoints.dart';

/// Family system API endpoints.
/// This file uses your existing kMainUrl, so you do not need to touch old API code.
const String kFamilyMyFamily = '$kMainUrl/my-family';
const String kFamilyList = '$kMainUrl/family-list';
const String kFamilyRanking = '$kMainUrl/family-ranking';
const String kFamilyCreate = '$kMainUrl/family-create';
const String kFamilyLeave = '$kMainUrl/family-leave';
const String kFamilyLevelList = '$kMainUrl/family-level-list';
const String kFamilyCurrentLevel = '$kMainUrl/family-current-level';
const String kFamilyBadgeList = '$kMainUrl/family-badge-list';
const String kFamilyRequestList = '$kMainUrl/family-request-list';
const String kFamilyCoinLogs = '$kMainUrl/family-coin-logs';
const String kFamilyContribute = '$kMainUrl/family-contribute';

String kFamilyDetail(int familyId) => '$kMainUrl/family-detail/$familyId';
String kFamilyJoin(int familyId) => '$kMainUrl/family-join/$familyId';
String kFamilyUpdate(int familyId) => '$kMainUrl/family-update/$familyId';
String kFamilyRequestAccept(int requestId) => '$kMainUrl/family-request-accept/$requestId';
String kFamilyRequestReject(int requestId) => '$kMainUrl/family-request-reject/$requestId';
String kFamilyRequestCancel(int requestId) => '$kMainUrl/family-request-cancel/$requestId';
String kFamilyMemberKick(int memberId) => '$kMainUrl/family-member-kick/$memberId';
String kFamilyMemberRole(int memberId) => '$kMainUrl/family-member-role/$memberId';
String kFamilyAnnouncements(int familyId) => '$kMainUrl/family-announcements?family_id=$familyId';
