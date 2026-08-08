import 'package:streaming_shared_preferences/streaming_shared_preferences.dart';

final Future<StreamingSharedPreferences> _prefs =
    StreamingSharedPreferences.instance;

setPeeredUserId(peeredUserId) async {
  await _prefs.then((value) {
    value.setInt("peeredUserId", peeredUserId);
  });
}

setPeeredUserName(peeredUserName) async {
  await _prefs.then((value) {
    value.setString("peeredUserName", peeredUserName);
  });
}

setPeeredUserImage(peeredUserImage) async {
  await _prefs.then((value) {
    value.setString("peeredUserImage", peeredUserImage);
  });
}

setPeeredUserCallType(peeredUserCallType) async {
  await _prefs.then((value) {
    value.setString("peeredUserCallType", peeredUserCallType);
  });
}

Future<int> getPeeredUserId() async {
  int id = 0;
  await _prefs.then((value) {
    id = value.getInt('peeredUserId', defaultValue: 0).getValue();
  });
  return id;
}

Future<String> getPeeredUserName() async {
  String name = "";
  await _prefs.then((value) {
    name = value.getString("peeredUserName", defaultValue: '').getValue();
  });
  return name;
}

Future<String> getPeeredUserImage() async {
  String name = "";
  await _prefs.then((value) {
    name = value.getString("peeredUserImage", defaultValue: '').getValue();
  });
  return name;
}

Future<String> getPeeredUserCallType() async {
  String peeredUserCallType = "";
  await _prefs.then((value) {
    peeredUserCallType =
        value.getString("peeredUserCallType", defaultValue: '').getValue();
  });
  return peeredUserCallType;
}
