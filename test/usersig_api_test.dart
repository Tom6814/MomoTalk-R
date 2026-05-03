import 'package:flutter_test/flutter_test.dart';
import 'package:momotalk/im/usersig_api.dart';

void main() {
  test('UsersigResponse parse', () {
    final resp = UsersigResponse.fromJson({
      'sdkAppId': 20039871,
      'userId': 'u1',
      'userSig': 'sig',
      'expireAt': 123,
    });
    expect(resp.sdkAppId, 20039871);
    expect(resp.userId, 'u1');
  });
}

