import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/models/payment_method_record.dart';

void main() {
  group('PaymentMethodRecord', () {
    test('parses provider-backed card fields', () {
      final record = PaymentMethodRecord.fromJson({
        'id': 1,
        'label': '',
        'provider': 'stripe',
        'provider_method_id': 'pm_123',
        'brand': 'visa',
        'last4': '4242',
        'exp_month': 1,
        'exp_year': 2030,
        'is_default': true,
      });

      expect(record.displayTitle, 'VISA •••• 4242');
      expect(record.expiryLabel, '01/2030');
      expect(record.isProviderBacked, isTrue);
    });
  });
}
