import 'package:flutter/services.dart';
import 'dart:async';

import 'channels.dart';

typedef MessageHandler = Future<dynamic> Function(MethodCall call);

class ClientMessageChannel {
  const ClientMessageChannel();

  Future<dynamic> invokeMethod(String method, [dynamic arguments]) {
    return windowEventChannel.invokeMethod(method, arguments);
  }

  void setMessageHandler(MessageHandler? handler) {
    windowEventChannel.setMethodCallHandler(handler);
  }
}

// window_channel.dart (or wherever you keep channels)

enum WindowEventType { close, focus, blur, show, hide }

class WindowEvent {
  final int windowId;
  final WindowEventType type;
  final Map<String, dynamic> payload;
  WindowEvent(this.windowId, this.type, [this.payload = const {}]);

  factory WindowEvent.fromMap(Map<dynamic, dynamic> map) {
    final type = switch (map['event'] as String) {
      'close' => WindowEventType.close,
      'focus' => WindowEventType.focus,
      'blur' => WindowEventType.blur,
      'show' => WindowEventType.show,
      'hide' => WindowEventType.hide,
      _ => WindowEventType.close,
    };
    return WindowEvent(
      map['windowId'] as int,
      type,
      (map['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

class WindowChannels {
  static const _events = EventChannel(
    'desktop_multi_window/events',
  ); // global event stream

  static Stream<WindowEvent>? _stream;
  static Stream<WindowEvent> get events =>
      _stream ??= _events.receiveBroadcastStream().map((e) {
        return WindowEvent.fromMap((e as Map).cast<dynamic, dynamic>());
      });
}

// ✅ Simple API you can expose to app code:
StreamSubscription<WindowEvent> onWindowClose(
  int windowId,
  void Function() handler,
) {
  return WindowChannels.events.listen((e) {
    if (e.type == WindowEventType.close && e.windowId == windowId) {
      handler();
    }
  });
}
