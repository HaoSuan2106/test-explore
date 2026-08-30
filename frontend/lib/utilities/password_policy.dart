/// The password policy shared by registration, password change and password
/// reset (UC101 C1 / UC103 C1): at least 8 characters, with an uppercase
/// letter, a lowercase letter, a number and a special character.
class PasswordPolicy {
  const PasswordPolicy._();

  static const int minimumLength = 8;

  static bool hasMinimumLength(String password) =>
      password.length >= minimumLength;

  static bool hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);

  static bool hasLowercase(String password) => RegExp(r'[a-z]').hasMatch(password);

  static bool hasNumber(String password) => RegExp(r'\d').hasMatch(password);

  static bool hasSymbol(String password) =>
      RegExp(r'[^A-Za-z0-9\s]').hasMatch(password);

  static bool isValid(String password) =>
      hasMinimumLength(password) &&
      hasUppercase(password) &&
      hasLowercase(password) &&
      hasNumber(password) &&
      hasSymbol(password);

  static String? validationError(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (!isValid(password)) {
      return 'Use at least 8 characters, including an uppercase letter, '
          'a lowercase letter, a number and a symbol';
    }
    return null;
  }
}
