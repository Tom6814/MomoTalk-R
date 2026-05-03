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

