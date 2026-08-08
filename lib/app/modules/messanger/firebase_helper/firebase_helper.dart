import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FireBaseHelper {
  // save user data
  void addNewUser(
      {required String isChatWith,
      required int uid,
      required String userStatus}) {
    FirebaseFirestore.instance.collection('users').doc('$uid').set({
      'userId': uid,
      'userStatus': userStatus,
      'chatWith': isChatWith,
    });
  }

  // get all Live Streaming
  Stream<QuerySnapshot<Map<String, dynamic>>> getLiveStreamingList() {
    return FirebaseFirestore.instance
        .collection('live_streams')
        .orderBy("datetime", descending: true)
        .snapshots();
  }

  void addLiveStream(
      {required String title, required int uid, required DateTime dateTime}) {
    FirebaseFirestore.instance.collection('live_streams').doc('$uid').set({
      'userId': uid,
      'title': title,
      'channelName': '$uid',
      'timestamp': dateTime,
      'datetime': dateTime,
      'views': [],
    });
  }

  void updateLiveStreamTimestamp(
      {required int uid, required DateTime dateTime}) {
    FirebaseFirestore.instance
        .collection('live_streams')
        .doc('$uid')
        .update({'timestamp': dateTime});
  }

  // update user status
  void updateUserStatus({required String userStatus, required int uid}) {
    FirebaseFirestore.instance
        .collection('users')
        .doc('$uid')
        .update({'userStatus': userStatus});
  }

  void updateCallStatus(
      {required BuildContext context,
      required String isChatWith,
      required int uid}) {
    FirebaseFirestore.instance
        .collection("users")
        .doc('$uid')
        .update({"chatWith": isChatWith});
  }

  // // send message to user
  // void sendMessage({required chatId,required senderId,required receiverId,required msgTime,required msgType,required message,required fileName}){
  //   FirebaseFirestore.instance
  //       .collection("messages")
  //       .doc(chatId)
  //       .collection(chatId)
  //       .doc("${Timestamp.now().millisecondsSinceEpoch}")
  //       .set({
  //     'chatId': chatId,
  //     'senderId': senderId,
  //     'receiverId': receiverId,
  //     'msgTime' : msgTime,
  //     'msgType':msgType,
  //     'message':message,
  //     'fileName':fileName,
  //   });
  // }

  // // get all messages
  // Stream<QuerySnapshot<Map<String, dynamic>>> getMessages(BuildContext context,
  //     {required String chatId}) {
  //   return FirebaseFirestore.instance
  //       .collection('messages')
  //       .doc(chatId)
  //       .collection(chatId)
  //       .orderBy("msgTime",descending: true)
  //       .snapshots();
  // }

  // // update last message
  // void updateLastMessage({required chatId,required senderId,required receiverId,required receiverUsername,required msgTime,required msgType,required message,required context}){

  //   lastMessageForPeerUser(receiverId,senderId, chatId, context, receiverUsername, msgTime, msgType, message);
  //   lastMessageForCurrentUser(receiverId,senderId, chatId, context, receiverUsername, msgTime, msgType, message);

  // }

  // void lastMessageForCurrentUser(receiverId,senderId, chatId, context, receiverUsername, msgTime, msgType, message) {
  //   FirebaseFirestore.instance
  //       .collection("lastMessages")
  //       .doc(senderId)
  //       .collection(senderId)
  //       .where('chatId', isEqualTo: chatId)
  //       .get().then((QuerySnapshot value) {
  //     if(value.size == 0){
  //       FirebaseFirestore.instance
  //           .collection("lastMessages")
  //           .doc(senderId)
  //           .collection(senderId)
  //           .doc("${Timestamp.now().millisecondsSinceEpoch}")
  //           .set({
  //         'chatId': chatId,
  //         'messageFrom' :Provider.of<MyProvider>(context,listen: false).auth.currentUser!.displayName ,
  //         'messageTo' :receiverUsername ,
  //         'messageSenderId': senderId,
  //         'messageReceiverId': receiverId,
  //         'msgTime' : msgTime,
  //         'msgType':msgType,
  //         'message':message,
  //       });
  //     }else{
  //       FirebaseFirestore.instance
  //           .collection("lastMessages")
  //           .doc(senderId)
  //           .collection(senderId)
  //           .doc(value.docs[0].id)
  //           .update({
  //         'messageFrom' :Provider.of<MyProvider>(context,listen: false).auth.currentUser!.displayName ,
  //         'messageTo' :receiverUsername ,
  //         'messageSenderId': senderId,
  //         'messageReceiverId': receiverId,
  //         'msgTime' : msgTime,
  //         'msgType':msgType,
  //         'message':message,
  //       });
  //     }
  //   });
  // }

  // void lastMessageForPeerUser(receiverId,senderId, chatId, context, receiverUsername, msgTime, msgType, message) {
  //   FirebaseFirestore.instance
  //       .collection("lastMessages")
  //       .doc(receiverId)
  //       .collection(receiverId)
  //       .where('chatId', isEqualTo: chatId)
  //       .get().then((QuerySnapshot value) {
  //     if(value.size == 0){
  //       FirebaseFirestore.instance
  //           .collection("lastMessages")
  //           .doc(receiverId)
  //           .collection(receiverId)
  //           .doc("${Timestamp.now().millisecondsSinceEpoch}")
  //           .set({
  //             'chatId': chatId,
  //             'messageFrom' :Provider.of<MyProvider>(context,listen: false).auth.currentUser!.displayName ,
  //             'messageTo' :receiverUsername ,
  //             'messageSenderId': senderId,
  //             'messageReceiverId': receiverId,
  //             'msgTime' : msgTime,
  //             'msgType':msgType,
  //             'message':message,
  //           });
  //     }else{
  //       FirebaseFirestore.instance
  //           .collection("lastMessages")
  //           .doc(receiverId)
  //           .collection(receiverId)
  //           .doc(value.docs[0].id)
  //           .update({
  //         'messageFrom' :Provider.of<MyProvider>(context,listen: false).auth.currentUser!.displayName ,
  //         'messageTo' :receiverUsername ,
  //         'messageSenderId': senderId,
  //         'messageReceiverId': receiverId,
  //         'msgTime' : msgTime,
  //         'msgType':msgType,
  //         'message':message,
  //       });
  //     }
  //   });
  // }

  // // get all last messages
  // Stream<QuerySnapshot<Map<String, dynamic>>> getLastMessages(BuildContext context, String myId) {
  //   return FirebaseFirestore.instance
  //       .collection('lastMessages')
  //       .doc(myId)
  //       .collection(myId)
  //       .orderBy("msgTime",descending: true)
  //       .snapshots();
  // }

  // UploadTask getRefrenceFromStorage(file,voiceMessageName, context){

  //   FirebaseStorage storage = FirebaseStorage.instance;
  //   Reference ref = storage.ref().child("Media")
  //   // ignore: use_build_context_synchronously
  //       .child(Provider.of<MyProvider>(context,listen: false).getChatId(context))
  //       // ignore: unrelated_type_equality_checks
  //       .child(file is File?voiceMessageName:file.runtimeType==FilePickerResult?file!.files.single.name:file!.name);
  //   return ref.putFile(file is File?file:File(file.runtimeType==FilePickerResult?file!.files.single.path:file.path));

  // }

}
