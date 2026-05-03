import 'package:momotalk/im/chat_repository.dart';

import 'chat_repository_factory_native.dart' if (dart.library.html) 'chat_repository_factory_web.dart';

ChatRepository createChatRepository() => createChatRepositoryImpl();

