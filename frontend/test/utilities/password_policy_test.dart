import 'package:explore_my/utilities/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy', () {
    test('accepts a password with eight characters, a number, and a symbol', () {
      expect(PasswordPolicy.isValid('Explore1!'), isTrue);
    });

    test('rejects a password shorter than eight characters', () {
      expect(PasswordPolicy.isValid('Abc1!'), isFalse);
    });

    test('rejects a password without a number', () {
      expect(PasswordPolicy.isValid('Explore!'), isFalse);
    });

    test('rejects a password without a symbol', () {
      expect(PasswordPolicy.isValid('Explore1'), isFalse);
    });
  });
}
