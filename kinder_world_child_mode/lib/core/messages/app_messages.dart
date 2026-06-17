abstract final class AuthUiMessages {
  static const invalidEmailOrPassword = 'Invalid email or password';
  static const loginFailedTryAgain = 'Login failed. Please try again.';
  static const twoFactorCodeRequired =
      'Two-factor authentication code is required';
  static const invalidTwoFactorCode = 'Invalid two-factor authentication code';
  static const registrationFailedTryAgain =
      'Registration failed. Please try again.';
  static const registrationFailedCheckInfo =
      'Registration failed. Please check your information.';
  static const registrationFailedEmptyServerResponse =
      'Registration failed: empty server response';
  static const registrationFailedInvalidUserData =
      'Registration failed: invalid user data';
  static const emailVerificationRequired =
      'Email verification is required before login';
  static const verificationCodeInvalid = 'Invalid or expired OTP';
  static const verificationCodeSent =
      'We sent a verification code to your email.';
  static const verificationCodeResent =
      'A new verification code has been sent.';
  static const verificationCodeCooldown =
      'Please wait before requesting another code.';
  static const passwordsDoNotMatch = 'Passwords do not match';
  static const passwordMinLength = 'Password must be at least 8 characters';
  static const parentAuthenticationRequired =
      'Parent authentication is required';
  static const failedToSetPin = 'Failed to set PIN';
  static const incorrectPin = 'Incorrect PIN';
  static const failedToVerifyPin = 'Failed to verify PIN';
  static const failedToChangePin = 'Failed to change PIN';
  static const failedToRequestPinReset = 'Failed to request PIN reset';
  static const logoutFailed = 'Logout failed';
  static const childLoginFailed = 'child_login_failed';
  static const childRegisterFailed = 'child_register_failed';
  static const currentPasswordCannotBeEmpty =
      'Current password cannot be empty';
  static const newPasswordCannotBeEmpty = 'New password cannot be empty';
  static const passwordStrengthRequirement =
      'Password must include uppercase, number, and special character';
  static const failedToChangePasswordCheckCurrent =
      'Failed to change password. Please check your current password.';
  static const changePasswordUnexpected =
      'An error occurred while changing password';

  static String formatStatusMessage({
    required int? statusCode,
    required String message,
  }) {
    final normalizedMessage = message.trim();
    if (statusCode == null) {
      return normalizedMessage;
    }
    if (normalizedMessage.isEmpty) {
      return '[$statusCode] Request failed';
    }
    return '[$statusCode] $normalizedMessage';
  }
}

abstract final class AdminAuthUiMessages {
  static const invalidEmailOrPassword = 'Invalid email or password';
  static const twoFactorCodeRequired =
      'Two-factor authentication code is required';
  static const invalidTwoFactorCode = 'Invalid two-factor authentication code';
  static const adminAccountDisabled = 'Admin account is disabled';
  static const adminAccountNotFound = 'Admin account not found';
  static const notAuthenticated = 'Not authenticated';
  static const noRefreshTokenStored = 'No refresh token stored';
  static const requestFailed = 'Request failed';
  static const networkError = 'Network error';

  static String unexpectedError(Object error) => 'Unexpected error: $error';
}

abstract final class AiBuddyUiMessages {
  static const authenticationRequired =
      'Authentication is required to use AI Buddy.';
  static const unavailable = 'AI Buddy is currently unavailable.';
  static const requestFailed = 'AI Buddy request failed.';
}
