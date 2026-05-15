import 'package:flutter_test/flutter_test.dart';
import 'package:nice_view/features/random_image/domain/quota_state.dart';
import 'package:nice_view/services/quota_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('legacy quota events migrate into random bucket on load', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'nice_view.quota_events': [
        now.toIso8601String(),
      ],
      'nice_view.server_lockout_until':
          now.add(const Duration(minutes: 5)).toIso8601String(),
    });
    final preferences = await SharedPreferences.getInstance();
    final service = QuotaService(preferences);

    final state = service.load();

    expect(state.usedFor(QuotaBucket.random), 1);
    expect(state.usedFor(QuotaBucket.image), 0);
    expect(state.isServerLockedFor(QuotaBucket.random), isTrue);
    expect(state.isServerLockedFor(QuotaBucket.image), isFalse);
  });
}
