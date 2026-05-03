## 背景

当前项目（MisonoTalk）是一个以本地消息列表为中心的 AI 聊天 UI，核心消息状态集中在 `MainPageState`，发送流程调用 OpenAI 兼容接口进行 SSE 流式返回（见 [main.dart](file:///workspace/lib/main.dart)、[openai.dart](file:///workspace/lib/openai.dart)）。

目标是将其改造成“真实 IM 聊天 App”，在尽量保持现有界面结构与交互习惯的前提下，接入腾讯云 Chat（Tencent Cloud Chat）SDK，实现加好友、单聊消息（文字/语音/图片/视频/文件）收发、会话列表、历史消息加载，并兼容 Web 平台。

## 重要安全约束

- SDKSecretKey 只能用于服务端签发 UserSig，必须存放在服务端环境变量/密钥管理系统中，严禁出现在 App、Web 前端代码或仓库中。
- 客户端只获取短期有效的 userSig，并通过 HTTPS + 鉴权接口获取。
- 不在日志中输出 userSig、鉴权 token 等敏感信息。

## 目标与范围

### 第一阶段（先做）

- 登录：通过输入 `userId`，从后端获取 `userSig`，完成 SDK 登录与初始化
- 好友：完整好友体系（搜索用户、发起申请、处理申请、好友列表、删除/拉黑）
- 会话：会话列表、未读数、最近消息预览、切换会话
- 单聊消息：文字、语音、图片、视频、文件的发送与接收
- 历史消息：进入会话加载最近 N 条；上拉分页加载更早消息
- 失败重试：发送失败可重发；网络断开后自动恢复基本可用状态
- Web：可用的 Web 端实现（允许语音交互与保存行为有降级）

### 第二阶段（后做）

- 群聊：建群/加人/退群/群资料
- 离线推送、已读回执、撤回、转发等增强能力（按需求取舍）

## 方案选择

采用“自研 UI + 官方 Chat SDK（推荐）”：

- 保留现有 Flutter UI 骨架（左侧列表 + 右侧聊天 + 底部输入）
- 新增一层统一的 IM 抽象接口，移动端与 Web 分别对接对应的腾讯云 Chat SDK
- UI 只依赖自家消息/会话/好友模型，屏蔽各端 SDK 对象差异

## 总体架构

### 分层

- UI 层（现有为主）：负责渲染会话列表、消息列表、输入区、弹窗菜单
- Domain 层（新增）：统一接口 `ChatRepository`，暴露登录、会话、好友、消息相关能力
- Infra 层（新增）：`ChatRepository` 的 Mobile/Web 两套实现
  - Mobile：对接腾讯云 Chat Flutter SDK（原生插件）
  - Web：对接腾讯云 Chat Web SDK（JS），由 Dart 进行封装
- Storage 层（改造）：用于 UI 草稿与轻量缓存；不再将 SharedPreferences 作为 IM 消息权威来源

### 现有代码的改造锚点

- 发送入口：`sendMsg()`（[main.dart](file:///workspace/lib/main.dart)）从调用 LLM 改为调用 `ChatRepository.sendText(...)`
- 左侧栏：`leftpanel.dart` 从静态壳改为会话列表数据源
- 消息渲染：`chatview.dart` 从 `Message.type` 扩展为多媒体消息渲染
- 长按菜单：`popups.dart` 从 AI 语义改为 IM 语义（复制/删除/重发/保存等）

## 后端设计（UserSig 签发服务）

### API

- `POST /v1/im/usersig`
  - 入参：`userId: string`
  - 出参：`sdkAppId: number`、`userId: string`、`userSig: string`、`expireAt: number`

### 规则

- SDKSecretKey 仅服务端持有
- 接口必须鉴权与限流（即使第一阶段 UI 允许“输入 userId 登录”，服务端也应限制滥用）
- userSig 设置合理过期（例如小时级），客户端过期后自动续签

## 客户端领域模型（替代 utils.dart 的 Message）

### ChatConversation

- `conversationId: String`
- `type: enum { c2c, group }`
- `title: String`
- `avatarUrl: String?`
- `unreadCount: int`
- `lastMessagePreview: String?`
- `lastMessageTime: int?`

### ChatUser

- `userId: String`
- `nick: String?`
- `avatarUrl: String?`
- `remark: String?`

### ChatMessage

- `msgId: String`
- `conversationId: String`
- `senderId: String`
- `isSelf: bool`
- `timestamp: int`
- `status: enum { sending, sent, failed }`
- `type: enum { text, image, video, voice, file, custom }`
- `payload: ChatMessagePayload`

`ChatMessagePayload` 为结构化数据，随类型变化，例如：

- text：`text`
- image：`localPath?`、`remoteUrl?`、`width?`、`height?`
- video：`localPath?`、`remoteUrl?`、`durationMs?`、`thumbUrl?`
- voice：`localPath?`、`remoteUrl?`、`durationMs`
- file：`localPath?`、`remoteUrl?`、`fileName`、`size`

## Domain 接口（统一 ChatRepository）

### Auth

- `Future<void> init({required int sdkAppId})`
- `Future<void> login({required String userId, required String userSig})`
- `Future<void> logout()`
- `Stream<AuthState> watchAuthState()`

### Conversations

- `Stream<List<ChatConversation>> watchConversations()`
- `Future<void> setCurrentConversation(String conversationId)`
- `Stream<List<ChatMessage>> watchCurrentMessages()`
- `Future<void> loadMoreMessages({required String conversationId})`
- `Future<void> markConversationRead(String conversationId)`

### Messages

- `Future<ChatMessage> sendText({required String conversationId, required String text})`
- `Future<ChatMessage> sendImage({required String conversationId, required String localPath})`
- `Future<ChatMessage> sendVideo({required String conversationId, required String localPath})`
- `Future<ChatMessage> sendFile({required String conversationId, required String localPath})`
- `Future<ChatMessage> sendVoice({required String conversationId, required String localPath, required int durationMs})`
- `Future<void> resend(String msgId)`
- `Future<void> delete(String msgId)`

### Friends

- `Stream<List<ChatUser>> watchFriends()`
- `Future<List<ChatUser>> searchUsers(String keywordOrUserId)`
- `Future<void> sendFriendRequest({required String toUserId, String? remark, String? addWording})`
- `Stream<List<FriendRequest>> watchFriendRequests()`
- `Future<void> acceptFriendRequest(String requestId)`
- `Future<void> rejectFriendRequest(String requestId)`
- `Future<void> deleteFriend(String userId)`
- `Future<void> blockUser(String userId)`

## UI 改造设计（尽量保持基本不变）

### 登录

- 新增一个轻量登录入口（弹窗/页面均可）
  - 输入 `userId`
  - 调后端获取 `userSig`
  - 调用 `ChatRepository.login`
- 保留现有 “Settings” 菜单入口，但其中的 AI 模型配置逐步迁移为 IM 配置（如环境、后端地址等）

### 左侧栏（会话列表）

改造 [leftpanel.dart](file:///workspace/lib/leftpanel.dart)：

- 数据源：`watchConversations()`
- 展示：头像/标题/最后一条消息预览/时间/未读角标
- 点击：`setCurrentConversation(conversationId)`，右侧切换消息流

### 右侧聊天（消息列表 + 输入区）

改造 [chatview.dart](file:///workspace/lib/chatview.dart)、[msgeditor.dart](file:///workspace/lib/msgeditor.dart)：

- 消息列表使用 `ChatMessage` 渲染多类型气泡
- 输入区增加：
  - 文本发送（保持原有）
  - “+”附件面板：相册/拍摄/文件
  - 语音：移动端按住说话；Web 端点击录音并发送（允许交互差异）

### 长按菜单

改造 [popups.dart](file:///workspace/lib/popups.dart)：

- 文本：复制/删除/重发（失败态）/引用（可选）
- 图片/视频/文件：保存/转发（可选）/删除/重发
- 语音：转文字（可选，后续）/删除/重发

### 好友页面

- 新增“好友”页：
  - 好友列表（点击进入单聊会话或创建会话）
  - 好友申请列表（同意/拒绝）
  - 搜索用户（按 userId/关键词）并发起好友申请
- 入口：挂在主菜单（[mainpopup.dart](file:///workspace/lib/mainpopup.dart)）或左侧栏顶部按钮

## Web 兼容策略

- 上层 Domain 接口不变，使用 Web SDK 实现 `ChatRepository` 的 web 版本
- 降级规则（第一阶段约束已确认）：
  - 语音：点击录音/停止/发送
  - 文件保存：以浏览器下载为主，不做系统级相册写入
  - 视频播放：浏览器原生能力为主

## 数据与存储策略

- 会话/消息的权威数据由 SDK 提供（含本地数据库/云端同步能力）
- SharedPreferences 只保存 UI 状态与轻量信息：
  - 最近登录的 userId（可选）
  - 当前会话 id、草稿、是否置顶（可选）
- 现有 `temp_history/history_*` 只保留给 AI 模式或作为过渡，不作为 IM 模式权威历史

## 迁移与开关策略

- 第一阶段保留 AI 模式代码但默认关闭，避免大规模删除引发回归
- 增加运行模式开关（IM / AI），便于回退与对比测试
- 后续可把 AI 作为一个“机器人账号”接入 IM 体系（可选，不在第一阶段必须范围）

## 验收清单（第一阶段）

- 能用输入 userId 登录并稳定在线
- 能搜索用户、发起/处理好友申请、显示好友列表
- 会话列表可见且未读数正确；点击会话可切换
- 单聊支持文字/图片/视频/文件/语音收发
- 进入会话加载历史，上拉可继续加载更早消息
- 发送失败可重发，UI 明确提示失败原因（网络/权限/文件不存在等）
- Web 端可完成登录、文字/图片/文件/语音（降级交互）基础收发

