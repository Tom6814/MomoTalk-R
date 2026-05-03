import 'package:momotalk/im/chat_repository.dart';
import 'package:momotalk/im/tim_chat_repository.dart';

ChatRepository createChatRepositoryImpl() => TimChatRepository();

