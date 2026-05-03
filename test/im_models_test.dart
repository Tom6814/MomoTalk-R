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

