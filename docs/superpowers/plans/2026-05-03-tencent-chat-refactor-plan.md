# Tencent Cloud Chat 改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将当前 AI 聊天 UI 改造成基于腾讯云 Chat SDK 的真实 IM 聊天 App（好友 + 单聊 + 多媒体消息 + Web 支持），并隐藏 AI 模式入口（代码保留但不可在 UI 中触发）。

**Architecture:** 新增 `ChatRepository` 抽象层与统一领域模型，Flutter（含 Web）通过 `tencent_cloud_chat_sdk` 对接腾讯云 Chat SDK；UI 继续沿用现有布局，只替换数据源与发送/接收逻辑。

**Tech Stack:** Flutter + Dart、tencent_cloud_chat_sdk、dio、shared_preferences、file_picker、record、just_audio、video_player、Node.js(Express) usersig 服务（tls-sig-api-v2）。

---

## 代码结构（本计划锁定）

**新增目录/文件（Flutter）**
- Create: `/workspace/lib/im/auth_state.dart`
- Create: `/workspace/lib/im/models.dart`
- Create: `/workspace/lib/im/chat_repository.dart`
- Create: `/workspace/lib/im/tim_chat_repository.dart`
- Create: `/workspace/lib/im/usersig_api.dart`
- Create: `/workspace/lib/im/im_controller.dart`
- Create: `/workspace/lib/im/login_dialog.dart`
- Create: `/workspace/lib/im/friends_page.dart`
- Create: `/workspace/lib/im/media/voice_recorder.dart`
- Create: `/workspace/lib/im/media/voice_player.dart`

**改造文件（Flutter UI）**
- Modify: `/workspace/lib/main.dart`
- Modify: `/workspace/lib/leftpanel.dart`
- Modify: `/workspace/lib/chatview.dart`
- Modify: `/workspace/lib/msgeditor.dart`
- Modify: `/workspace/lib/mainpopup.dart`
- Modify: `/workspace/lib/configpage.dart`
- Modify: `/workspace/lib/popups.dart`

**新增目录/文件（后端 usersig 服务）**
- Create: `/workspace/server/usersig/package.json`
- Create: `/workspace/server/usersig/index.js`
- Create: `/workspace/server/usersig/README.md`
- Create: `/workspace/server/usersig/.gitignore`

**测试**
- Create: `/workspace/test/im_models_test.dart`
- Create: `/workspace/test/usersig_api_test.dart`
- Create: `/workspace/test/im_controller_test.dart`

---

## Task 1: 依赖接入（Flutter + Web）

**Files:**
- Modify: `/workspace/pubspec.yaml`
- Create: `/workspace/web/package.json`
- Create: `/workspace/web/package-lock.json`（由 npm 生成）
- Modify: `/workspace/web/index.html`

- [ ] **Step 1: 更新 Flutter 依赖（先写入 pubspec.yaml）**

在 `/workspace/pubspec.yaml` 的 `dependencies:` 增加：

```yaml
  tencent_cloud_chat_sdk: ^8.9.7540+2
  record: ^5.2.0
  just_audio: ^0.9.39
  video_player: ^2.9.2
```

- [ ] **Step 2: 拉取依赖**

Run:

```bash
flutter pub get
```

Expected: exit code 0

- [ ] **Step 3: 配置 Flutter Web 所需 JS（按官方 Flutter Web 接入说明）**

Run:

```bash
cd web && npm init -y
cd web && npm i tim-js-sdk tim-upload-plugin
```

Expected: `web/package.json` 与 `web/package-lock.json` 生成，node_modules 出现

- [ ] **Step 4: 修改 web/index.html 引入 JS**

在 `/workspace/web/index.html` 的 `<head>` 中加入：

```html
<script src="./node_modules/tim-upload-plugin/index.js"></script>
<script src="./node_modules/tim-js-sdk/tim-js-friendship.js"></script>
```

- [ ] **Step 5: 验证 Web 构建不报错**

Run:

```bash
flutter build web --release
```

Expected: build success

---

## Task 2: 领域模型与仓储接口（可单测）

**Files:**
- Create: `/workspace/lib/im/auth_state.dart`
- Create: `/workspace/lib/im/models.dart`
- Create: `/workspace/lib/im/chat_repository.dart`
- Test: `/workspace/test/im_models_test.dart`

- [ ] **Step 1: 写单测（先失败）**

Create `/workspace/test/im_models_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:momotalk/im/models.dart';

void main() {
  test('ChatMessage text payload', () {
    const msg = ChatMessage(
      msgId: 'm1',
      conversationId: 'c1',
      senderId: 'u1',
      isSelf: true,
      timestamp: 123,
      status: ChatMessageStatus.sent,
      type: ChatMessageType.text,
      payload: ChatMessagePayload.text('hi'),
    );

    expect(msg.payload.text, 'hi');
    expect(msg.type, ChatMessageType.text);
  });
}
```

- [ ] **Step 2: 跑测试确认失败（因为文件不存在）**

Run:

```bash
flutter test test/im_models_test.dart
```

Expected: FAIL（找不到 `momotalk/im/models.dart` 或类型未定义）

- [ ] **Step 3: 实现模型与枚举**

Create `/workspace/lib/im/models.dart`：

```dart
import 'package:flutter/foundation.dart';

enum ChatConversationType { c2c, group }

@immutable
class ChatConversation {
  const ChatConversation({
    required this.conversationId,
    required this.type,
    required this.title,
    this.avatarUrl,
    required this.unreadCount,
    this.lastMessagePreview,
    this.lastMessageTime,
  });

  final String conversationId;
  final ChatConversationType type;
  final String title;
  final String? avatarUrl;
  final int unreadCount;
  final String? lastMessagePreview;
  final int? lastMessageTime;
}

@immutable
class ChatUser {
  const ChatUser({
    required this.userId,
    this.nick,
    this.avatarUrl,
    this.remark,
  });

  final String userId;
  final String? nick;
  final String? avatarUrl;
  final String? remark;
}

enum ChatMessageStatus { sending, sent, failed }
enum ChatMessageType { text, image, video, voice, file, custom }

@immutable
class ChatMessagePayload {
  const ChatMessagePayload._({
    this.text,
    this.localPath,
    this.remoteUrl,
    this.fileName,
    this.size,
    this.durationMs,
    this.thumbUrl,
    this.width,
    this.height,
  });

  final String? text;
  final String? localPath;
  final String? remoteUrl;
  final String? fileName;
  final int? size;
  final int? durationMs;
  final String? thumbUrl;
  final int? width;
  final int? height;

  const ChatMessagePayload.text(String text) : this._(text: text);

  const ChatMessagePayload.file({
    required String localPath,
    required String fileName,
    int? size,
    String? remoteUrl,
  }) : this._(
          localPath: localPath,
          fileName: fileName,
          size: size,
          remoteUrl: remoteUrl,
        );

  const ChatMessagePayload.image({
    required String localPath,
    String? remoteUrl,
    int? width,
    int? height,
  }) : this._(
          localPath: localPath,
          remoteUrl: remoteUrl,
          width: width,
          height: height,
        );

  const ChatMessagePayload.video({
    required String localPath,
    String? remoteUrl,
    int? durationMs,
    String? thumbUrl,
  }) : this._(
          localPath: localPath,
          remoteUrl: remoteUrl,
          durationMs: durationMs,
          thumbUrl: thumbUrl,
        );

  const ChatMessagePayload.voice({
    required String localPath,
    String? remoteUrl,
    required int durationMs,
  }) : this._(
          localPath: localPath,
          remoteUrl: remoteUrl,
          durationMs: durationMs,
        );
}

@immutable
class ChatMessage {
  const ChatMessage({
    required this.msgId,
    required this.conversationId,
    required this.senderId,
    required this.isSelf,
    required this.timestamp,
    required this.status,
    required this.type,
    required this.payload,
  });

  final String msgId;
  final String conversationId;
  final String senderId;
  final bool isSelf;
  final int timestamp;
  final ChatMessageStatus status;
  final ChatMessageType type;
  final ChatMessagePayload payload;
}
```

Create `/workspace/lib/im/auth_state.dart`：

```dart
import 'package:flutter/foundation.dart';

@immutable
class AuthState {
  const AuthState._({required this.isLoggedIn, this.userId});

  final bool isLoggedIn;
  final String? userId;

  const AuthState.loggedOut() : this._(isLoggedIn: false);
  const AuthState.loggedIn(String userId) : this._(isLoggedIn: true, userId: userId);
}
```

- [ ] **Step 4: 定义 ChatRepository 接口**

Create `/workspace/lib/im/chat_repository.dart`：

```dart
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
  Future<ChatMessage> sendVoice({required String conversationId, required String localPath, required int durationMs});

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
```

- [ ] **Step 5: 重新跑测试**

Run:

```bash
flutter test test/im_models_test.dart
```

Expected: PASS

---

## Task 3: usersig 后端服务（Node/Express，可本地运行）

**Files:**
- Create: `/workspace/server/usersig/package.json`
- Create: `/workspace/server/usersig/index.js`
- Create: `/workspace/server/usersig/README.md`
- Create: `/workspace/server/usersig/.gitignore`

- [ ] **Step 1: 创建 package.json**

Create `/workspace/server/usersig/package.json`：

```json
{
  "name": "momotalk-usersig",
  "private": true,
  "type": "commonjs",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^4.19.2",
    "tls-sig-api-v2": "^1.1.1"
  }
}
```

- [ ] **Step 2: 实现 usersig 接口**

Create `/workspace/server/usersig/index.js`：

```js
const express = require('express');
const cors = require('cors');
const TLSSigAPIv2 = require('tls-sig-api-v2');

const app = express();
app.use(cors());
app.use(express.json());

const SDK_APP_ID = Number(process.env.SDK_APP_ID || '0');
const SDK_SECRET_KEY = process.env.SDK_SECRET_KEY || '';
const EXPIRE_SECONDS = Number(process.env.EXPIRE_SECONDS || String(3600));

if (!SDK_APP_ID || !SDK_SECRET_KEY) {
  throw new Error('Missing SDK_APP_ID or SDK_SECRET_KEY');
}

const api = new TLSSigAPIv2.Api(SDK_APP_ID, SDK_SECRET_KEY);

app.post('/v1/im/usersig', (req, res) => {
  const userId = String(req.body?.userId || '').trim();
  if (!userId) {
    res.status(400).json({ error: 'userId required' });
    return;
  }
  const userSig = api.genSig(userId, EXPIRE_SECONDS);
  const expireAt = Math.floor(Date.now() / 1000) + EXPIRE_SECONDS;
  res.json({ sdkAppId: SDK_APP_ID, userId, userSig, expireAt });
});

const port = Number(process.env.PORT || '8080');
app.listen(port, () => {
  process.stdout.write(`usersig service listening on ${port}\n`);
});
```

- [ ] **Step 3: README 与 .gitignore**

Create `/workspace/server/usersig/.gitignore`：

```gitignore
node_modules
.env
```

Create `/workspace/server/usersig/README.md`：

```md
## usersig service

Run:

```bash
cd server/usersig
npm i
SDK_APP_ID=20039871 SDK_SECRET_KEY=YOUR_SECRET_KEY PORT=8080 npm start
```

Request:

```bash
curl -X POST http://localhost:8080/v1/im/usersig -H 'Content-Type: application/json' -d '{"userId":"test_user"}'
```
```

- [ ] **Step 4: 本地验证服务可跑通**

Run:

```bash
cd server/usersig && npm i
SDK_APP_ID=20039871 SDK_SECRET_KEY=xxxx PORT=8080 node index.js
```

Expected: 输出 `usersig service listening on 8080`

---

## Task 4: Flutter 端 usersig API + 登录弹窗 + 最小控制器

**Files:**
- Create: `/workspace/lib/im/usersig_api.dart`
- Create: `/workspace/lib/im/im_controller.dart`
- Create: `/workspace/lib/im/login_dialog.dart`
- Modify: `/workspace/lib/main.dart`
- Test: `/workspace/test/usersig_api_test.dart`
- Test: `/workspace/test/im_controller_test.dart`

- [ ] **Step 1: usersig API 单测（先失败）**

Create `/workspace/test/usersig_api_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:momotalk/im/usersig_api.dart';

void main() {
  test('UsersigResponse parse', () {
    final resp = UsersigResponse.fromJson({
      'sdkAppId': 20039871,
      'userId': 'u1',
      'userSig': 'sig',
      'expireAt': 123,
    });
    expect(resp.sdkAppId, 20039871);
    expect(resp.userId, 'u1');
  });
}
```

- [ ] **Step 2: 实现 UsersigApi**

Create `/workspace/lib/im/usersig_api.dart`：

```dart
import 'package:dio/dio.dart';

class UsersigResponse {
  UsersigResponse({
    required this.sdkAppId,
    required this.userId,
    required this.userSig,
    required this.expireAt,
  });

  final int sdkAppId;
  final String userId;
  final String userSig;
  final int expireAt;

  factory UsersigResponse.fromJson(Map<String, dynamic> json) {
    return UsersigResponse(
      sdkAppId: (json['sdkAppId'] as num).toInt(),
      userId: json['userId'] as String,
      userSig: json['userSig'] as String,
      expireAt: (json['expireAt'] as num).toInt(),
    );
  }
}

class UsersigApi {
  UsersigApi({required Dio dio, required this.baseUrl}) : _dio = dio;

  final Dio _dio;
  final String baseUrl;

  Future<UsersigResponse> getUserSig({required String userId}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/v1/im/usersig',
      data: {'userId': userId},
      options: Options(responseType: ResponseType.json),
    );
    return UsersigResponse.fromJson(resp.data!);
  }
}
```

- [ ] **Step 3: 控制器骨架（只负责：登录态、当前会话、消息流挂载）**

Create `/workspace/lib/im/im_controller.dart`：

```dart
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
```

- [ ] **Step 4: 登录弹窗**

Create `/workspace/lib/im/login_dialog.dart`：

```dart
import 'package:flutter/material.dart';

class LoginResult {
  const LoginResult(this.userId);
  final String userId;
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登录'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(hintText: '输入 userId'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final v = _ctrl.text.trim();
            if (v.isEmpty) return;
            Navigator.of(context).pop(LoginResult(v));
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: 控制器单测（用 fake repo）**

Create `/workspace/test/im_controller_test.dart`：

```dart
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
  Future<ChatMessage> sendVoice({required String conversationId, required String localPath, required int durationMs}) async => throw UnimplementedError();

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
```

- [ ] **Step 6: 跑测试**

Run:

```bash
flutter test test/usersig_api_test.dart test/im_controller_test.dart
```

Expected: PASS

- [ ] **Step 7: main.dart 接入控制器并强制 IM 模式**

按以下步骤改造 `main.dart`：

1. App 启动时初始化 `ImController.init(sdkAppId: 20039871)`。
2. 如果 `authState.isLoggedIn == false`，自动弹出 `LoginDialog`：
   - `UsersigApi(baseUrl: <从设置读取，默认 http://localhost:8080>)`
   - `getUserSig(userId)` 获取 userSig
   - 调 `ImController.login(...)`
3. 禁用/隐藏 AI 相关入口：`mainpopup.dart`、`configpage.dart` 中移除 AI 配置、Prompt 编辑、AI Draw、历史 AI 记录入口；`openai.dart` 保留但不再被引用。

验收：未登录时无法发送消息；登录后能看到会话列表（若无会话则空态）。

---

## Task 5: TimChatRepository（基于 tencent_cloud_chat_sdk 的真实实现）

**Files:**
- Create: `/workspace/lib/im/tim_chat_repository.dart`
- Modify: `/workspace/lib/main.dart`

核心 SDK API（来自 tencent_cloud_chat_sdk）：
- `TencentImSDKPlugin.v2TIMManager.initSDK(sdkAppID: ..., loglevel: LogLevelEnum.V2TIM_LOG_DEBUG, listener: V2TimSDKListener(...))`
- `TencentImSDKPlugin.v2TIMManager.login(userID: ..., userSig: ...)`
- `TencentImSDKPlugin.v2TIMManager.getConversationManager().getConversationList(nextSeq: "...", count: ...)`
- `TencentImSDKPlugin.v2TIMManager.getMessageManager().getC2CHistoryMessageList(userID: ..., count: ..., lastMsg: ...)`
- `TencentImSDKPlugin.v2TIMManager.getMessageManager().addAdvancedMsgListener(listener: V2TimAdvancedMsgListener(onRecvNewMessage: ...))`
- 发送消息采用“create + sendMessage”：
  - `createTextMessage(text: ...)` / `createImageMessage(imagePath: ...)` / `createVideoMessage(...)` / `createFileMessage(...)` / `createSoundMessage(...)`
  - `sendMessage(id: createdMsgID, receiver: <userId>, groupID: "", ...)`

- [ ] **Step 1: 实现 TimChatRepository（最小闭环：登录 + 会话列表 + 当前会话消息流 + 文本收发 + 历史拉取）**

Create `/workspace/lib/im/tim_chat_repository.dart`（关键实现片段，完整文件按此拼装）：

```dart
import 'dart:async';
import 'package:momotalk/im/auth_state.dart';
import 'package:momotalk/im/chat_repository.dart';
import 'package:momotalk/im/models.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_application_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_response_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/friend_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/log_level_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum_V2TimAdvancedMsgListener/V2TimAdvancedMsgListener.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_application.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_search_param.dart';

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
          if (_currentConversationId == null) return;
          final converted = _toChatMessage(msg, conversationId: _currentConversationId!);
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
    final id = c.conversationID ?? '';
    final title = c.showName ?? id;
    final lastMsg = c.lastMessage?.textElem?.text;
    return ChatConversation(
      conversationId: id,
      type: (c.type == 1) ? ChatConversationType.c2c : ChatConversationType.group,
      title: title,
      avatarUrl: c.faceUrl,
      unreadCount: c.unreadCount ?? 0,
      lastMessagePreview: lastMsg,
      lastMessageTime: c.lastMessage?.timestamp,
    );
  }

  @override
  Future<void> setCurrentConversation(String conversationId) async {
    _currentConversationId = conversationId;
    _currentMessages.clear();
    _lastC2CMsg = null;
    _messages.add(const <ChatMessage>[]);
    final parts = conversationId.split('_');
    if (parts.length >= 2 && parts.first == 'c2c') {
      _currentC2CUserId = parts.sublist(1).join('_');
    } else if (conversationId.startsWith('c2c_')) {
      _currentC2CUserId = conversationId.substring(4);
    } else if (conversationId.startsWith('C2C_')) {
      _currentC2CUserId = conversationId.substring(4);
    }
    await loadMoreMessages(conversationId: conversationId);
  }

  @override
  Future<void> loadMoreMessages({required String conversationId}) async {
    if (_currentC2CUserId == null) return;
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .getC2CHistoryMessageList(userID: _currentC2CUserId!, count: 20, lastMsg: _lastC2CMsg);
    final list = (res.data ?? <V2TimMessage>[])
        .map((m) => _toChatMessage(m, conversationId: conversationId))
        .toList(growable: false);
    if (list.isNotEmpty) {
      _lastC2CMsg = res.data!.last;
      _currentMessages.addAll(list.reversed);
      _messages.add(List<ChatMessage>.unmodifiable(_currentMessages));
    }
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
    if (_currentC2CUserId == null) {
      throw StateError('No current C2C user');
    }
    final createRes = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .createTextMessage(text: text);
    final created = createRes.data as V2TimMsgCreateInfoResult;
    final sendRes = await TencentImSDKPlugin.v2TIMManager.getMessageManager().sendMessage(
      id: created.id!,
      receiver: _currentC2CUserId!,
      groupID: '',
    );
    final msg = sendRes.data!;
    final converted = _toChatMessage(msg, conversationId: conversationId);
    _currentMessages.insert(0, converted);
    _messages.add(List<ChatMessage>.unmodifiable(_currentMessages));
    await _refreshConversationList();
    return converted;
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
        isSearchUserID: true,
        isSearchNickName: true,
      ),
    );
    final users = r.data?.userInfoList ?? <V2TimUserFullInfo>[];
    return users
        .map((u) => ChatUser(userId: u.userID!, nick: u.nickName, avatarUrl: u.faceUrl))
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
    final list = (r.data ?? <V2TimFriendInfo>[])
        .map((f) => ChatUser(
              userId: f.userID!,
              nick: f.userProfile?.nickName,
              avatarUrl: f.userProfile?.faceUrl,
              remark: f.friendRemark,
            ))
        .toList(growable: false);
    _friends.add(list);
  }

  Future<void> _refreshFriendRequests() async {
    final r = await TencentImSDKPlugin.v2TIMManager.getFriendshipManager().getFriendApplicationList();
    final apps = r.data?.friendApplicationList ?? <V2TimFriendApplication>[];
    final list = apps
        .map((a) => FriendRequest(
              userId: a.userID!,
              nick: a.nickname,
              avatarUrl: a.faceUrl,
              wording: a.addWording,
            ))
        .toList(growable: false);
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
```

- [ ] **Step 2: 在 main.dart 用 TimChatRepository 替换 FakeRepo**

`ImController(repo: TimChatRepository())`，并确保初始化只执行一次。

- [ ] **Step 3: 手工验证（移动端/Chrome）**

Run:

```bash
flutter run -d chrome
```

Expected: 登录弹窗出现 → 输入 userId → 调后端 usersig → 登录成功

---

## Task 6: UI 改造（会话列表/消息列表/输入区，保持基本结构）

**Files:**
- Modify: `/workspace/lib/leftpanel.dart`
- Modify: `/workspace/lib/chatview.dart`
- Modify: `/workspace/lib/msgeditor.dart`
- Modify: `/workspace/lib/popups.dart`

- [ ] **Step 1: leftpanel 改为消费 ImController.conversations**

实现要点：
- 空态：显示“暂无会话”
- 点击会话：`controller.setCurrentConversation(conversationId)`
- 未读数：显示 `unreadCount`

- [ ] **Step 2: chatview 渲染 ChatMessage（至少 text）**

实现要点：
- 先让 text 气泡正确显示（自发在右侧，对方在左侧）
- 后续多媒体逐步补齐（Task 7）

- [ ] **Step 3: msgeditor 发送文本调用 controller.sendText**

实现要点：
- 发送按钮调用 `controller.sendText(text)`，成功后清空输入框
- 未选择会话时：发送按钮 disabled 或 toast

- [ ] **Step 4: popups 长按菜单改为 IM 语义（文本：复制/删除）**

实现要点：
- 复制使用 `Clipboard.setData`
- 删除调用 `ChatRepository` 增补接口（若第一阶段暂不实现 delete，可先只做复制）

---

## Task 7: 多媒体消息（图片/视频/文件/语音）收发与播放

**Files:**
- Modify: `/workspace/lib/msgeditor.dart`
- Modify: `/workspace/lib/chatview.dart`
- Create: `/workspace/lib/im/media/voice_recorder.dart`
- Create: `/workspace/lib/im/media/voice_player.dart`
- Modify: `/workspace/lib/im/tim_chat_repository.dart`

- [ ] **Step 1: 语音录制与播放封装**

Create `/workspace/lib/im/media/voice_recorder.dart`：

```dart
import 'package:record/record.dart';

class VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();

  Future<bool> hasPermission() => _rec.hasPermission();

  Future<void> start(String path) => _rec.start(const RecordConfig(), path: path);

  Future<String?> stop() => _rec.stop();

  Future<void> dispose() => _rec.dispose();
}
```

Create `/workspace/lib/im/media/voice_player.dart`：

```dart
import 'package:just_audio/just_audio.dart';

class VoicePlayer {
  final AudioPlayer _p = AudioPlayer();

  Future<void> playPath(String path) async {
    await _p.setFilePath(path);
    await _p.play();
  }

  Future<void> stop() => _p.stop();

  Future<void> dispose() => _p.dispose();
}
```

- [ ] **Step 2: msgeditor 增加附件按钮（使用 file_picker）**

实现要点：
- 图片：`FilePicker.platform.pickFiles(type: FileType.image)`
- 视频：`FilePicker.platform.pickFiles(type: FileType.video)`
- 文件：`FilePicker.platform.pickFiles(type: FileType.any)`
- 语音：移动端按住录音（Web 端点击开始/停止）

- [ ] **Step 3: TimChatRepository 实现 sendImage/sendVideo/sendFile/sendVoice**

实现要点（基于 `createXxxMessage` + `sendMessage`）：
- `createImageMessage(imagePath: localPath)`
- `createFileMessage(filePath: localPath, fileName: basename(localPath))`
- `createSoundMessage(soundPath: localPath, duration: durationMs ~/ 1000)`
- `createVideoMessage(videoFilePath: ..., type: 'mp4', duration: ..., snapshotPath: ...)`（第一阶段 snapshotPath 可先不实现视频缩略图，允许先用 file 方式发送视频）

- [ ] **Step 4: chatview 多媒体展示**

实现要点：
- 图片：优先本地 `Image.file`，否则远端 url `Image.network`
- 文件：显示文件名 + 点击用 `url_launcher` 打开远端 url 或本地路径
- 语音：显示“▶︎ + 时长”，点击播放本地/远端下载后播放（第一阶段可先只支持本地播放）
- 视频：第一阶段可先点击打开远端 url；后续再用 `video_player` 内嵌播放

---

## Task 8: 好友页面（搜索/申请/处理/列表 -> 发起单聊）

**Files:**
- Create: `/workspace/lib/im/friends_page.dart`
- Modify: `/workspace/lib/mainpopup.dart`
- Modify: `/workspace/lib/main.dart`

- [ ] **Step 1: friends_page UI（3 个 tab：好友/申请/搜索）**

Create `/workspace/lib/im/friends_page.dart`（结构要点）：
- 好友列表：`controller.repo.watchFriends()` 或 controller 增加 ValueNotifier
- 申请列表：同上
- 搜索：输入 userId/关键词 → `repo.searchUsers` → 列表展示 → 点击“添加好友”
- 点击好友：拼出 `conversationId`（按 SDK 规则，优先使用 SDK 返回的 conversationId；若需自拼则 `C2C_<userId>`），然后 `controller.setCurrentConversation(...)` 并返回聊天页

- [ ] **Step 2: 主菜单入口增加“好友”，移除 AI 入口**

在 `/workspace/lib/mainpopup.dart`：
- 增加：`Friends`
- 移除：PromptEditor/AI Draw/History/Records/Msgs 等 AI 相关菜单（代码可保留但不提供入口）

- [ ] **Step 3: 手工验收路径**

1. 登录 A、登录 B
2. A 搜索 B → 发起好友申请
3. B 申请列表同意
4. A 与 B 进入单聊会话互发文本/图片/文件/语音

---

## Task 9: 最终验收与回归（不提交 secret）

**Files:**
- Modify: `/workspace/README.md`（增加“usersig 服务启动方式”与“Web 需要 npm install”说明）

- [ ] **Step 1: 运行全部 Flutter 测试**

Run:

```bash
flutter test
```

Expected: PASS

- [ ] **Step 2: Web 构建**

Run:

```bash
flutter build web --release
```

Expected: PASS

- [ ] **Step 3: 自查仓库中不包含 SDKSecretKey**

Run:

```bash
git grep -n "SDKSecretKey" || true
git grep -n "6ab599e4566535596ac0fc486c21fa" || true
```

Expected: 无匹配
