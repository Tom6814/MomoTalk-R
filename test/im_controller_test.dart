import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:momotalk/im/auth_state.dart';
import 'package:momotalk/im/chat_repository.dart';
import 'package:momotalk/im/im_controller.dart';
import 'package:momotalk/im/models.dart';

class FakeRepo implements ChatRepository {
  final _auth = StreamController<AuthState>.broadcast();
  final _convs = StreamController<List<ChatConversation>>.broadcast();
  final _msgs = StreamController<List<ChatMessage>>.broadcast();

  @override
  Stream<AuthState> watchAuthState() => _auth.stream;
  @override
  Stream<List<ChatConversation>> watchConversations() => _convs.stream;
  @override
  Stream<List<ChatMessage>> watchCurrentMessages() => _msgs.stream;

  @override
  Future<void> init({required int sdkAppId}) async {}
  @override
  Future<void> login({required String userId, required String userSig}) async {
    _auth.add(AuthState.loggedIn(userId));
  }
  @override
  Future<void> logout() async {
    _auth.add(const AuthState.loggedOut());
  }

  @override
  Future<void> setCurrentConversation(String conversationId) async {}
  @override
  Future<void> loadMoreMessages({required String conversationId}) async {}
  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  Future<ChatMessage> sendText({required String conversationId, required String text}) async {
    return ChatMessage(
      msgId: 'm1',
      conversationId: conversationId,
      senderId: 'me',
      isSelf: true,
      timestamp: 0,
      status: ChatMessageStatus.sent,
      type: ChatMessageType.text,
      payload: ChatMessagePayload.text(text),
    );
  }

  @override
  Future<ChatMessage> sendImage({required String conversationId, required String localPath}) async => throw UnimplementedError();
  @override
  Future<ChatMessage> sendVideo({required String conversationId, required String localPath}) async => throw UnimplementedError();
  @override
  Future<ChatMessage> sendFile({required String conversationId, required String localPath}) async => throw UnimplementedError();
  @override
  Future<ChatMessage> sendVoice({
    required String conversationId,
    required String localPath,
    required int durationMs,
  }) async =>
      throw UnimplementedError();

  @override
  Stream<List<ChatUser>> watchFriends() => const Stream.empty();
  @override
  Future<List<ChatUser>> searchUsers(String keywordOrUserId) async => <ChatUser>[];
  @override
  Future<void> sendFriendRequest({required String toUserId, String? remark, String? addWording}) async {}
  @override
  Stream<List<FriendRequest>> watchFriendRequests() => const Stream.empty();
  @override
  Future<void> acceptFriendRequest(String requestUserId) async {}
  @override
  Future<void> rejectFriendRequest(String requestUserId) async {}
  @override
  Future<void> deleteFriend(String userId) async {}
  @override
  Future<void> blockUser(String userId) async {}
}

void main() {
  test('ImController mirrors auth stream', () async {
    final repo = FakeRepo();
    final c = ImController(repo: repo);
    await c.login(userId: 'u1', userSig: 'sig');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(c.authState.value.isLoggedIn, true);
    expect(c.authState.value.userId, 'u1');
    c.dispose();
  });
}

