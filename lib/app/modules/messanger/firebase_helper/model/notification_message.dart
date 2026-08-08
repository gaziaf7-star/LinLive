import 'dart:convert';

class NotificationMessage {
  Data? data;

  NotificationMessage({this.data});

  NotificationMessage.fromJson(Map<String, dynamic> json) {
    data =
        json['data'] != null ? Data.fromJson(jsonDecode(json['data'])) : null;
  }
}

class Data {
  String? title;
  String? message;
  String? image;
  int? peeredUid;
  String? peeredName;
  String? callType;

  Data(
      {this.image,
      this.title,
      this.message,
      this.peeredUid,
      this.peeredName,
      this.callType});

  Data.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    message = json['message'];
    image = json['image'];
    peeredUid = json['peeredUid'];
    peeredName = json['peeredName'];
    callType = json['callType'];
  }
}
