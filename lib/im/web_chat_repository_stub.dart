import 'dart:async';

import 'package:momotalk/im/auth_state.dart';
import 'package:momotalk/im/chat_repository.dart';
import 'package:momotalk/im/models.dart';

class WebChatRepositoryStub implements ChatRepository {
  final _auth = StreamController<AuthState>.broadcast();
  final _conversations = StreamController<List<ChatConversation>>.broadcast();
  final _messages = StreamController<List<ChatMessage>>.broadcast();
  final _friends = StreamController<List<ChatUser>>.broadcast();
  final _friendReqs = StreamController<List<FriendRequest>>.broadcast();

  final List<ChatMessage> _currentMessages = <ChatMessage>[];
  String? _currentConversationId;
  int _seq = 0;

  WebChatRepositoryStub() {
    _auth.add(const AuthState.loggedOut());
    _conversations.add(const <ChatConversation>[
      ChatConversation(
        conversationId: 'c2c_echo',
        type: ChatConversationType.c2c,
        title: 'Echo',
        avatarUrl: null,
        unreadCount: 0,
        lastMessagePreview: null,
        lastMessageTime: null,
      ),
    ]);
    _messages.add(const <ChatMessage>[]);
    _friends.add(const <ChatUser>[]);
    _friendReqs.add(const <FriendRequest>[]);
  }

  @override
  Stream<AuthState> watchAuthState() => _auth.stream;

  @override
  Future<void> init({required int sdkAppId}) async {}

  @override
  Future<void> login({required String userId, required String userSig}) async {
    _auth.add(AuthState.loggedIn(userId));
  }

  @override
  Future<void> logout() async {
    _currentConversationId = null;
    _currentMessages.clear();
    _messages.add(const <ChatMessage>[]);
    _auth.add(const AuthState.loggedOut());
  }

  @override
  Stream<List<ChatConversation>> watchConversations() => _conversations.stream;

  @override
  Future<void> setCurrentConversation(String conversationId) async {
    _currentConversationId = conversationId;
    _currentMessages.clear();
    _messages.add(const <ChatMessage>[]);
  }

  @override
  Stream<List<ChatMessage>> watchCurrentMessages() => _messages.stream;

  @override
  Future<void> loadMoreMessages({required String conversationId}) async {}

  @override
  Future<void> markConversationRead(String conversationId) async {}

  @override
  Future<ChatMessage> sendText({required String conversationId, required String text}) async {
    if (_currentConversationId != conversationId) {
      throw StateError('No current conversation');
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final msgId = 'm_${now}_${_seq++}';
    final selfMsg = ChatMessage(
      msgId: msgId,
      conversationId: conversationId,
      senderId: 'me',
      isSelf: true,
      timestamp: now,
      status: ChatMessageStatus.sent,
      type: ChatMessageType.text,
      payload: ChatMessagePayload.text(text),
    );
    _currentMessages.insert(0, selfMsg);
    _messages.add(List<ChatMessage>.unmodifiable(_currentMessages));

    await Future<void>.delayed(const Duration(milliseconds: 250));
    final echoMsg = ChatMessage(
      msgId: '${msgId}_echo',
      conversationId: conversationId,
      senderId: 'echo',
      isSelf: false,
      timestamp: now,
      status: ChatMessageStatus.sent,
      type: ChatMessageType.text,
      payload: ChatMessagePayload.text(text),
    );
    _currentMessages.insert(0, echoMsg);
    _messages.add(List<ChatMessage>.unmodifiable(_currentMessages));
    return selfMsg;
  }

  @override
  Future<ChatMessage> sendImage({required String conversationId, required String localPath}) {
    throw UnsupportedError('Web stub: sendImage not supported');
  }

  @override
  Future<ChatMessage> sendVideo({required String conversationId, required String localPath}) {
    throw UnsupportedError('Web stub: sendVideo not supported');
  }

  @override
  Future<ChatMessage> sendFile({required String conversationId, required String localPath}) {
    throw UnsupportedError('Web stub: sendFile not supported');
  }

  @override
  Future<ChatMessage> sendVoice({
    required String conversationId,
    required String localPath,
    required int durationMs,
  }) {
    throw UnsupportedError('Web stub: sendVoice not supported');
  }

  @override
  Stream<List<ChatUser>> watchFriends() => _friends.stream;

  @override
  Future<List<ChatUser>> searchUsers(String keywordOrUserId) async => const <ChatUser>[];

  @override
  Future<void> sendFriendRequest({required String toUserId, String? remark, String? addWording}) async {}

  @override
  Stream<List<FriendRequest>> watchFriendRequests() => _friendReqs.stream;

  @override
  Future<void> acceptFriendRequest(String requestUserId) async {}

  @override
  Future<void> rejectFriendRequest(String requestUserId) async {}

  @override
  Future<void> deleteFriend(String userId) async {}

  @override
  Future<void> blockUser(String userId) async {}
}

