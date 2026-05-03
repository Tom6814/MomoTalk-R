import 'package:flutter/widgets.dart';

enum TitleBarStyle { hidden }

class WindowOptions {
  const WindowOptions({this.titleBarStyle});
  final TitleBarStyle? titleBarStyle;
}

class _WindowManager {
  Future<void> ensureInitialized() async {}

  void waitUntilReadyToShow(WindowOptions options, Future<void> Function() callback) {
    callback();
  }

  Future<void> show() async {}
  Future<void> focus() async {}
  Future<void> close() async {}
  Future<void> setAlwaysOnTop(bool isAlwaysOnTop) async {}
}

final windowManager = _WindowManager();

class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

