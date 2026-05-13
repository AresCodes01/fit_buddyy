import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';

abstract class SocialRepository {
  Future<void> createGroup(String name, String userId);
  Future<void> joinGroup(String groupId, String userId);
  Stream<List<Map<String, dynamic>>> getGroups(List<String> groupIds);
  Stream<List<UserModel>> getGroupMembers(String groupId);
  Future<void> sendMessage(String gId, String uId, String uName, String msg);
  Stream<QuerySnapshot> getMessages(String gId);
  Future<Map<String, dynamic>?> getGroupById(String groupId);
}
