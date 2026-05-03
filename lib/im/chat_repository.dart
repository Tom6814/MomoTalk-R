import 'dart:async';

import 'package:momotalk/im/auth_state.dart';
import 'package:momotalk/im/models.dart';

abstract class ChatRepository {
  Stream<AuthState> watchAuthState();

  Future<void> init({required int sdkAppId});
  Future<void> login({required String userId, required String userSig});
  Future<void> logout();

  Stream<List<ChatConversation>> watchConversations();
  Future<void> setCurrentConversation(String conversationId);
  Stream<List<ChatMessage>> watchCurrentMessages();
  Future<void> loadMoreMessages({required String conversationId});
  Future<void> markConversationRead(String conversationId);

  Future<ChatMessage> sendText({required String conversationId, required String text});
  Future<ChatMessage> sendImage({required String conversationId, required String localPath});
  Future<ChatMessage> sendVideo({required String conversationId, required String localPath});
  Future<ChatMessage> sendFile({required String conversationId, required String localPath});
  Future<ChatMessage> sendVoice({
    required String conversationId,
    required String localPath,
    required int durationMs,
  });

  Stream<List<ChatUser>> watchFriends();
  Future<List<ChatUser>> searchUsers(String keywordOrUserId);
  Future<void> sendFriendRequest({required String toUserId, String? remark, String? addWording});
  Stream<List<FriendRequest>> watchFriendRequests();
  Future<void> acceptFriendRequest(String requestUserId);
  Future<void> rejectFriendRequest(String requestUserId);
  Future<void> deleteFriend(String userId);
  Future<void> blockUser(String userId);
}

class FriendRequest {
  const FriendRequest({
    required this.userId,
    this.nick,
    this.avatarUrl,
    this.wording,
  });

  final String userId;
  final String? nick;
  final String? avatarUrl;
  final String? wording;
}

