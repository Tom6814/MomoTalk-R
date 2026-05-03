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

