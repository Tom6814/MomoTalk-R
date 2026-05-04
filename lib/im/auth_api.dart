import 'package:dio/dio.dart';

class AuthResponse {
  AuthResponse({required this.userId});

  final String userId;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(userId: json['userId'] as String);
  }
}

class AuthApiException implements Exception {
  AuthApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthApi {
  AuthApi({required Dio dio, required this.baseUrl}) : _dio = dio;

  final Dio _dio;
  final String baseUrl;

  Future<AuthResponse> register({required String username, required String password}) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/v1/auth/register',
        data: {'username': username, 'password': password},
        options: Options(responseType: ResponseType.json),
      );
      return AuthResponse.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<AuthResponse> login({required String username, required String password}) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '$baseUrl/v1/auth/login',
        data: {'username': username, 'password': password},
        options: Options(responseType: ResponseType.json),
      );
      return AuthResponse.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  AuthApiException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final code = (data is Map && data['error'] is Map) ? (data['error']['code'] as String?) : null;
    if (status == 409 || code == 'USERNAME_EXISTS') {
      return AuthApiException('用户名已存在', code: code);
    }
    if (status == 401 || code == 'INVALID_CREDENTIALS') {
      return AuthApiException('用户名或密码错误', code: code);
    }
    if (status == 400 && (code == 'INVALID_USERNAME' || code == 'INVALID_PASSWORD')) {
      return AuthApiException('用户名或密码格式不正确', code: code);
    }
    return AuthApiException('请求失败', code: code);
  }
}

