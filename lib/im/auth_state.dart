import 'package:flutter/foundation.dart';

@immutable
class AuthState {
  const AuthState._({required this.isLoggedIn, this.userId});

  final bool isLoggedIn;
  final String? userId;

  const AuthState.loggedOut() : this._(isLoggedIn: false);
  const AuthState.loggedIn(String userId) : this._(isLoggedIn: true, userId: userId);
}

