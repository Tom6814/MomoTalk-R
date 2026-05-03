import 'package:dio/dio.dart';

class UsersigResponse {
  UsersigResponse({
    required this.sdkAppId,
    required this.userId,
    required this.userSig,
    required this.expireAt,
  });

  final int sdkAppId;
  final String userId;
  final String userSig;
  final int expireAt;

  factory UsersigResponse.fromJson(Map<String, dynamic> json) {
    return UsersigResponse(
      sdkAppId: (json['sdkAppId'] as num).toInt(),
      userId: json['userId'] as String,
      userSig: json['userSig'] as String,
      expireAt: (json['expireAt'] as num).toInt(),
    );
  }
}

class UsersigApi {
  UsersigApi({required Dio dio, required this.baseUrl}) : _dio = dio;

  final Dio _dio;
  final String baseUrl;

  Future<UsersigResponse> getUserSig({required String userId}) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/v1/im/usersig',
      data: {'userId': userId},
      options: Options(responseType: ResponseType.json),
    );
    return UsersigResponse.fromJson(resp.data!);
  }
}

