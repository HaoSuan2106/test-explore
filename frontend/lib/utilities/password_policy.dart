class PasswordPolicy {
  const PasswordPolicy._();

  static const int minimumLength = 8;

  static bool hasMinimumLength(String password) =>
      password.length >= minimumLength;

  static bool hasNumber(String password) => RegExp(r'\d').hasMatch(password);

  static bool hasSymbol(String password) =>
      RegExp(r'[^A-Za-z0-9\s]').hasMatch(password);

  static bool isValid(String password) =>
      hasMinimumLength(password) && hasNumber(password) && hasSymbol(password);

  static String? validationError(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (!isValid(password)) {
      return 'Use at least 8 characters, including a number and a symbol';
    }
    return null;
  }
}
