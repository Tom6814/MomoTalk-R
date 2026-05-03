import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:momotalk/im/chat_repository.dart';
import 'package:momotalk/im/chat_repository_factory.dart';
import 'package:momotalk/im/im_controller.dart';
import 'package:momotalk/im/login_dialog.dart';
import 'package:momotalk/im/models.dart';
import 'package:momotalk/im/usersig_api.dart';

class ImPage extends StatefulWidget {
  const ImPage({super.key});

  @override
  State<ImPage> createState() => _ImPageState();
}

class _ImPageState extends State<ImPage> {
  static const _sdkAppId = 20039871;
  static const _defaultUsersigBaseUrl = 'http://localhost:8080';

  late final ChatRepository _repo;
  late final ImController _controller;
  late final UsersigApi _usersigApi;

  final _inputCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repo = createChatRepository();
    _controller = ImController(repo: _repo);
    _usersigApi = UsersigApi(dio: Dio(), baseUrl: _defaultUsersigBaseUrl);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _controller.init(sdkAppId: _sdkAppId);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureLoggedIn();
    });
  }

  Future<void> _ensureLoggedIn() async {
    if (_controller.authState.value.isLoggedIn) return;
    final r = await showDialog<LoginResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoginDialog(),
    );
    if (r == null) return;
    try {
      final sig = await _usersigApi.getUserSig(userId: r.userId);
      await _controller.login(userId: sig.userId, userSig: sig.userSig);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登录失败：$e')),
      );
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 320,
              child: ValueListenableBuilder<List<ChatConversation>>(
                valueListenable: _controller.conversations,
                builder: (context, convs, _) {
                  if (convs.isEmpty) {
                    return const Center(child: Text('暂无会话'));
                  }
                  return ListView.builder(
                    itemCount: convs.length,
                    itemBuilder: (context, index) {
                      final c = convs[index];
                      final avatarText = c.title.isEmpty ? '?' : c.title.substring(0, 1);
                      return ListTile(
                        leading: CircleAvatar(child: Text(avatarText)),
                        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(c.lastMessagePreview ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: c.unreadCount > 0 ? Text('${c.unreadCount}') : null,
                        selected: _controller.currentConversationId == c.conversationId,
                        onTap: () async {
                          await _controller.setCurrentConversation(c.conversationId);
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<List<ChatMessage>>(
                      valueListenable: _controller.messages,
                      builder: (context, msgs, _) {
                        if (msgs.isEmpty) {
                          return const Center(child: Text('暂无消息'));
                        }
                        return ListView.builder(
                          reverse: true,
                          itemCount: msgs.length,
                          itemBuilder: (context, index) {
                            final m = msgs[index];
                            final isSelf = m.isSelf;
                            final text = m.type == ChatMessageType.text ? (m.payload.text ?? '') : '[Unsupported]';
                            return Align(
                              alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                constraints: const BoxConstraints(maxWidth: 520),
                                decoration: BoxDecoration(
                                  color: isSelf ? const Color(0xFF4C5B70) : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  text,
                                  style: TextStyle(color: isSelf ? Colors.white : Colors.black87),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputCtrl,
                            decoration: const InputDecoration(
                              hintText: '输入消息',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            minLines: 1,
                            maxLines: 4,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final text = _inputCtrl.text.trim();
                            if (text.isEmpty) return;
                            await _controller.sendText(text);
                            _inputCtrl.clear();
                          },
                          child: const Text('发送'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
