import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:momotalk/im/auth_state.dart';
import 'package:momotalk/im/chat_repository.dart';
import 'package:momotalk/im/models.dart';

class ImController {
  ImController({required ChatRepository repo}) : _repo = repo {
    _authSub = _repo.watchAuthState().listen((s) {
      authState.value = s;
    });
    _convSub = _repo.watchConversations().listen((list) {
      conversations.value = list;
    });
    _msgSub = _repo.watchCurrentMessages().listen((list) {
      messages.value = list;
    });
  }

  final ChatRepository _repo;

  final ValueNotifier<AuthState> authState = ValueNotifier<AuthState>(const AuthState.loggedOut());
  final ValueNotifier<List<ChatConversation>> conversations = ValueNotifier<List<ChatConversation>>(<ChatConversation>[]);
  final ValueNotifier<List<ChatMessage>> messages = ValueNotifier<List<ChatMessage>>(<ChatMessage>[]);

  StreamSubscription<AuthState>? _authSub;
  StreamSubscription<List<ChatConversation>>? _convSub;
  StreamSubscription<List<ChatMessage>>? _msgSub;

  String? currentConversationId;

  Future<void> init({required int sdkAppId}) => _repo.init(sdkAppId: sdkAppId);

  Future<void> login({required String userId, required String userSig}) => _repo.login(userId: userId, userSig: userSig);

  Future<void> logout() async {
    currentConversationId = null;
    await _repo.logout();
  }

  Future<void> setCurrentConversation(String conversationId) async {
    currentConversationId = conversationId;
    await _repo.setCurrentConversation(conversationId);
    await _repo.markConversationRead(conversationId);
  }

  Future<void> loadMore() async {
    final cid = currentConversationId;
    if (cid == null) return;
    await _repo.loadMoreMessages(conversationId: cid);
  }

  Future<void> sendText(String text) async {
    final cid = currentConversationId;
    if (cid == null) return;
    await _repo.sendText(conversationId: cid, text: text);
  }

  void dispose() {
    _authSub?.cancel();
    _convSub?.cancel();
    _msgSub?.cancel();
    authState.dispose();
    conversations.dispose();
    messages.dispose();
  }
}

