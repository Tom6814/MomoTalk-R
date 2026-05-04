import 'package:flutter_test/flutter_test.dart';
import 'package:momotalk/im/auth_api.dart';

void main() {
  test('AuthResponse parse', () {
    final r = AuthResponse.fromJson({'userId': 'alice_01'});
    expect(r.userId, 'alice_01');
  });
}

