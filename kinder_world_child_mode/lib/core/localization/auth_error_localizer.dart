import 'package:kinder_world/core/localization/app_localizations.dart';
import 'package:kinder_world/core/messages/app_messages.dart';

String localizeAuthErrorMessage(String message, AppLocalizations l10n) {
  final normalized = message.trim();
  final normalizedLower = normalized.toLowerCase();

  if (normalizedLower.contains('connection refused') ||
      normalizedLower.contains('connection errored') ||
      normalizedLower.contains('socketexception') ||
      normalizedLower.contains('failed host lookup') ||
      normalizedLower.contains('connection error')) {
    return l10n.connectionError;
  }

  if (normalized == AuthUiMessages.invalidEmailOrPassword ||
      normalizedLower.contains('invalid credentials') ||
      normalizedLower.contains('[401]')) {
    return l10n.authInvalidEmailOrPassword;
  }
  if (normalized == AuthUiMessages.loginFailedTryAgain) {
    return l10n.loginFailed;
  }
  if (normalized == AuthUiMessages.registrationFailedTryAgain ||
      normalized == AuthUiMessages.registrationFailedCheckInfo) {
    return l10n.registrationFailed;
  }
  if (normalized == AuthUiMessages.twoFactorCodeRequired) {
    return l10n.authTwoFactorCodeRequired;
  }
  if (normalized == AuthUiMessages.invalidTwoFactorCode) {
    return l10n.authInvalidTwoFactorCode;
  }
  if (normalized == AdminAuthUiMessages.adminAccountDisabled) {
    return l10n.adminDisabledAccount;
  }
  if (normalized == AdminAuthUiMessages.adminAccountNotFound) {
    return l10n.adminAccountNotFoundMessage;
  }
  if (normalized == AdminAuthUiMessages.notAuthenticated) {
    return l10n.notAuthenticatedMessage;
  }
  if (normalized == AdminAuthUiMessages.requestFailed) {
    return l10n.requestFailedMessage;
  }
  if (normalized == AdminAuthUiMessages.networkError) {
    return l10n.networkErrorMessage;
  }
  return normalized;
}
