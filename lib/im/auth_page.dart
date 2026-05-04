import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:momotalk/im/auth_api.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.api});

  final AuthApi api;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _loginUsernameCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  final _regUsernameCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _regConfirmCtrl = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _loginUsernameCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regUsernameCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _doLogin() async {
    final username = _loginUsernameCtrl.text.trim();
    final password = _loginPasswordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      _toast('请输入用户名和密码');
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await widget.api.login(username: username, password: password);
      if (!mounted) return;
      Navigator.of(context).pop(r.userId);
    } on AuthApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('登录失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doRegister() async {
    final username = _regUsernameCtrl.text.trim();
    final password = _regPasswordCtrl.text;
    final confirm = _regConfirmCtrl.text;
    if (username.isEmpty || password.isEmpty || confirm.isEmpty) {
      _toast('请完整填写注册信息');
      return;
    }
    if (password != confirm) {
      _toast('两次密码不一致');
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await widget.api.register(username: username, password: password);
      if (!mounted) return;
      Navigator.of(context).pop(r.userId);
    } on AuthApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('注册失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('账号'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '登录'),
              Tab(text: '注册'),
            ],
          ),
          actions: [
            if (kIsWeb)
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        final id = _loginUsernameCtrl.text.trim().isEmpty ? 'web_demo' : _loginUsernameCtrl.text.trim();
                        Navigator.of(context).pop(id);
                      },
                child: const Text('Demo'),
              ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _loading,
          child: TabBarView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _loginUsernameCtrl,
                      decoration: const InputDecoration(labelText: '用户名'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _loginPasswordCtrl,
                      decoration: const InputDecoration(labelText: '密码'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _doLogin,
                        child: _loading ? const Text('处理中...') : const Text('登录'),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _regUsernameCtrl,
                      decoration: const InputDecoration(labelText: '用户名'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _regPasswordCtrl,
                      decoration: const InputDecoration(labelText: '密码'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _regConfirmCtrl,
                      decoration: const InputDecoration(labelText: '确认密码'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _doRegister,
                        child: _loading ? const Text('处理中...') : const Text('注册并登录'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

