import 'package:momotalk/im/chat_repository.dart';
import 'package:momotalk/im/web_chat_repository_stub.dart';

ChatRepository createChatRepositoryImpl() => WebChatRepositoryStub();

