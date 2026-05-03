import 'dart:async';

import 'package:momotalk/im/auth_state.dart';
import 'package:momotalk/im/chat_repository.dart';
import 'package:momotalk/im/models.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_response_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_search_result.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

class TimChatRepository implements ChatRepository {
  final _auth = StreamController<AuthState>.broadcast();
  final _conversations = StreamController<List<ChatConversation>>.broadcast();
  final _messages = StreamController<List<ChatMessage>>.broadcast();
  final _friends = StreamController<List<ChatUser>>.broadcast();
  final _friendReqs = StreamController<List<FriendRequest>>.broadcast();

  final List<ChatMessage> _currentMessages = <ChatMessage>[];
  String? _currentConversationId;
  String? _currentC2CUserId;
  V2TimMessage? _lastC2CMsg;

  @override
  Stream<AuthState> watchAuthState() => _auth.stream;

  @override
  Stream<List<ChatConversation>> watchConversations() => _conversations.stream;

  @override
  Stream<List<ChatMessage>> watchCurrentMessages() => _messages.stream;

  @override
  Stream<List<ChatUser>> watchFriends() => _friends.stream;

  @override
  Stream<List<FriendRequest>> watchFriendRequests() => _friendReqs.stream;

  @override
  Future<void> init({required int sdkAppId}) async {
    await TencentImSDKPlugin.v2TIMManager.initSDK(
      sdkAppID: sdkAppId,
      loglevel: LogLevelEnum.V2TIM_LOG_DEBUG,
      showImLog: true,
    );

    await TencentImSDKPlugin.v2TIMManager.getMessageManager().addAdvancedMsgListener(
      listener: V2TimAdvancedMsgListener(
        onRecvNewMessage: (V2TimMessage msg) {
          final cid = _currentConversationId;
          if (cid == null) return;
          final converted = _toChatMessage(msg, conversationId: cid);
          _currentMessages.insert(0, converted);
          _messages.add(List<ChatMessage>.unmodifiable(_currentMessages));
        },
      ),
    );
  }

  @override
  Future<void> login({required String userId, required String userSig}) async {
    await TencentImSDKPlugin.v2TIMManager.login(userID: userId, userSig: userSig);
    _auth.add(AuthState.loggedIn(userId));
    await _refreshConversationList();
    await _refreshFriendList();
    await _refreshFriendRequests();
  }

  @override
  Future<void> logout() async {
    await TencentImSDKPlugin.v2TIMManager.logout();
    _currentConversationId = null;
    _currentC2CUserId = null;
    _lastC2CMsg = null;
    _currentMessages.clear();
    _messages.add(const <ChatMessage>[]);
    _conversations.add(const <ChatConversation>[]);
    _friends.add(const <ChatUser>[]);
    _friendReqs.add(const <FriendRequest>[]);
    _auth.add(const AuthState.loggedOut());
  }

  Future<void> _refreshConversationList() async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .getConversationList(nextSeq: '0', count: 100);
    final list = (res.data?.conversationList ?? <V2TimConversation>[])
        .map(_toConversation)
        .toList(growable: false);
    _conversations.add(list);
  }

  ChatConversation _toConversation(V2TimConversation c) {
    final id = c.conversationID;
    final title = c.showName ?? id;
    final lastText = c.lastMessage?.textElem?.text;
    return ChatConversation(
      conversationId: id,
      type: (c.type == 1) ? ChatConversationType.c2c : ChatConversationType.group,
      title: title,
      avatarUrl: c.faceUrl,
      unreadCount: c.unreadCount ?? 0,
      lastMessagePreview: lastText,
      lastMessageTime: c.lastMessage?.timestamp,
    );
  }

  @override
  Future<void> setCurrentConversation(String conversationId) async {
    _currentConversationId = conversationId;
    _currentMessages.clear();
    _lastC2CMsg = null;
    _messages.add(const <ChatMessage>[]);

    if (conversationId.startsWith('c2c_')) {
      _currentC2CUserId = conversationId.substring(4);
    } else if (conversationId.startsWith('C2C_')) {
      _currentC2CUserId = conversationId.substring(4);
    } else {
      _currentC2CUserId = null;
    }

    await loadMoreMessages(conversationId: conversationId);
  }

  @override
  Future<void> loadMoreMessages({required String conversationId}) async {
    final userId = _currentC2CUserId;
    if (userId == null) return;
    final res = await TencentImSDKPlugin.v2TIMManager.getMessageManager().getC2CHistoryMessageList(
          userID: userId,
          count: 20,
          lastMsg: _lastC2CMsg,
        );
    final list = (res.data ?? <V2TimMessage>[])
        .map((m) => _toChatMessage(m, conversationId: conversationId))
        .toList(growable: false);
    if (list.isEmpty) return;
    _lastC2CMsg = res.data!.last;
    _currentMessages.addAll(list.reversed);
    _messages.add(List<ChatMessage>.unmodifiable(_currentMessages));
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await TencentImSDKPlugin.v2TIMManager.getConversationManager().cleanConversationUnreadMessageCount(
          conversationID: conversationId,
          cleanTimestamp: now,
          cleanSequence: 0,
        );
    await _refreshConversationList();
  }

  @override
  Future<ChatMessage> sendText({required String conversationId, required String text}) async {
    final receiver = _currentC2CUserId;
    if (receiver == null) {
      throw StateError('No current conversation');
    }
    final createRes = await TencentImSDKPlugin.v2TIMManager.getMessageManager().createTextMessage(text: text);
    final created = createRes.data as V2TimMsgCreateInfoResult;
    final sendRes = await TencentImSDKPlugin.v2TIMManager.getMessageManager().sendMessage(
          id: created.id!,
          receiver: receiver,
          groupID: '',
        );
    final msg = sendRes.data!;
    final converted = _toChatMessage(msg, conversationId: conversationId);
    _currentMessages.insert(0, converted);
    _messages.add(List<ChatMessage>.unmodifiable(_currentMessages));
    await _refreshConversationList();
    return converted;
  }

  @override
  Future<ChatMessage> sendImage({required String conversationId, required String localPath}) {
    throw UnimplementedError();
  }

  @override
  Future<ChatMessage> sendVideo({required String conversationId, required String localPath}) {
    throw UnimplementedError();
  }

  @override
  Future<ChatMessage> sendFile({required String conversationId, required String localPath}) {
    throw UnimplementedError();
  }

  @override
  Future<ChatMessage> sendVoice({
    required String conversationId,
    required String localPath,
    required int durationMs,
  }) {
    throw UnimplementedError();
  }

  ChatMessage _toChatMessage(V2TimMessage m, {required String conversationId}) {
    final elemType = m.elemType;
    if (elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT) {
      final text = m.textElem?.text ?? '';
      return ChatMessage(
        msgId: m.msgID ?? '',
        conversationId: conversationId,
        senderId: m.sender ?? '',
        isSelf: m.isSelf ?? false,
        timestamp: m.timestamp ?? 0,
        status: ChatMessageStatus.sent,
        type: ChatMessageType.text,
        payload: ChatMessagePayload.text(text),
      );
    }
    return ChatMessage(
      msgId: m.msgID ?? '',
      conversationId: conversationId,
      senderId: m.sender ?? '',
      isSelf: m.isSelf ?? false,
      timestamp: m.timestamp ?? 0,
      status: ChatMessageStatus.sent,
      type: ChatMessageType.custom,
      payload: const ChatMessagePayload.text('[Unsupported]'),
    );
  }

  @override
  Future<List<ChatUser>> searchUsers(String keywordOrUserId) async {
    final r = await TencentImSDKPlugin.v2TIMManager.searchUsers(
      searchParam: V2TimUserSearchParam(
        keywordList: <String>[keywordOrUserId],
      ),
    );
    final users = (r.data ?? V2TimUserSearchResult()).userInfoList ?? <V2TimUserInfo>[];
    return users
        .where((u) => u.userID.isNotEmpty)
        .map((u) => ChatUser(userId: u.userID, nick: u.nickName, avatarUrl: u.faceUrl))
        .toList(growable: false);
  }

  @override
  Future<void> sendFriendRequest({required String toUserId, String? remark, String? addWording}) async {
    await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().addFriend(
          userID: toUserId,
          remark: remark,
          addWording: addWording,
          addSource: 'momotalk',
          addType: FriendTypeEnum.V2TIM_FRIEND_TYPE_SINGLE,
        );
    await _refreshFriendRequests();
  }

  Future<void> _refreshFriendList() async {
    final r = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendList();
    final raw = r.data ?? <V2TimFriendInfo?>[];
    final list = raw.whereType<V2TimFriendInfo>().where((f) => f.userID.isNotEmpty).map((f) {
      return ChatUser(
        userId: f.userID,
        nick: f.userProfile?.nickName,
        avatarUrl: f.userProfile?.faceUrl,
        remark: f.friendRemark,
      );
    }).toList(growable: false);
    _friends.add(list);
  }

  Future<void> _refreshFriendRequests() async {
    final r = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendApplicationList();
    final res = r.data ?? V2TimFriendApplicationResult();
    final apps = res.friendApplicationList ?? <V2TimFriendApplication?>[];
    final list = apps.whereType<V2TimFriendApplication>().where((a) => a.userID.isNotEmpty).map((a) {
      return FriendRequest(
        userId: a.userID,
        nick: a.nickname,
        avatarUrl: a.faceUrl,
        wording: a.addWording,
      );
    }).toList(growable: false);
    _friendReqs.add(list);
  }

  @override
  Future<void> acceptFriendRequest(String requestUserId) async {
    await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().acceptFriendApplication(
          responseType: FriendResponseTypeEnum.V2TIM_FRIEND_ACCEPT_AGREE,
          type: FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_COME_IN,
          userID: requestUserId,
        );
    await _refreshFriendList();
    await _refreshFriendRequests();
  }

  @override
  Future<void> rejectFriendRequest(String requestUserId) async {
    await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().refuseFriendApplication(
          type: FriendApplicationTypeEnum.V2TIM_FRIEND_APPLICATION_COME_IN,
          userID: requestUserId,
        );
    await _refreshFriendRequests();
  }

  @override
  Future<void> deleteFriend(String userId) async {
    await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().deleteFromFriendList(
          userIDList: <String>[userId],
          deleteType: FriendTypeEnum.V2TIM_FRIEND_TYPE_SINGLE,
        );
    await _refreshFriendList();
  }

  @override
  Future<void> blockUser(String userId) async {
    await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().addToBlackList(
          userIDList: <String>[userId],
        );
  }
}
