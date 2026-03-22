// Custom exceptions used across the application.

class AuthException implements Exception {
  final String message;
  AuthException([this.message = 'Authentication error']);

  @override
  String toString() => 'AuthException: $message';
}

class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'Network error']);

  @override
  String toString() => 'NetworkException: $message';
}
