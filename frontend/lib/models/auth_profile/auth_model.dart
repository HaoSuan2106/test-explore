class RegisterRequest{
  const RegisterRequest({
   required this.username,
   required this.email,
   required this.password,
  });

  final String username;
  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
    'username': username,
    'email': email,
    'password': password,
  };
}

class RegisterResponse {
  const RegisterResponse({
    required this.userId,
    required this.username,
    required this.email,
    required this.accountStatus,
  });

  final int userId;
  final String username;
  final String email;
  final String accountStatus;

  factory RegisterResponse.fromJson(Map<String, dynamic> json) => RegisterResponse(
    userId: json['userId'] as int,
    username: json['username'] as String,
    email: json['email'] as String,
    accountStatus: json['accountStatus'] as String,
  );
}

class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
  };

}

class LoginResponse {
  const LoginResponse({
    required this.userId,
    required this.username,
    required this.email,
    required this.token,
    required this.expiresAtUtc,
    required this.refreshToken,
  });

  final int userId;
  final String username;
  final String email;
  final String token;
  final DateTime expiresAtUtc;
  final String refreshToken;

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    userId: json['userId'] as int,
    username: json['username'] as String,
    email: json['email'] as String,
    token: json['token'] as String,
    expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String),
    refreshToken: json['refreshToken'] as String,
  );
}

class VerifyEmailRequest {
  const VerifyEmailRequest({required this.email, required this.code});

  final String email;
  final String code;

  Map<String, dynamic> toJson() => {'email': email, 'code': code};
}

class ResendVerificationRequest {
  const ResendVerificationRequest({required this.email});

  final String email;

  Map<String, dynamic> toJson() => {'email': email};
}