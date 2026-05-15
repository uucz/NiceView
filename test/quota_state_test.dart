import 'package:flutter_test/flutter_test.dart';
import 'package:nice_view/features/random_image/domain/quota_state.dart';

void main() {
  test('quota buckets count requests independently', () {
    final now = DateTime.now();
    final state = QuotaState.initial()
        .consume(QuotaBucket.random, now)
        .consume(QuotaBucket.image, now)
        .consume(QuotaBucket.image, now.add(const Duration(seconds: 1)));

    expect(state.usedFor(QuotaBucket.random), 1);
    expect(state.usedFor(QuotaBucket.image), 2);
    expect(state.remainingFor(QuotaBucket.random), 79);
    expect(state.remainingFor(QuotaBucket.image), 48);
  });

  test('quota buckets recover independently', () {
    final now = DateTime.now();
    var state = QuotaState.initial();
    for (var index = 0; index < state.random.limit; index += 1) {
      state = state.consume(QuotaBucket.random, now);
    }
    state = state.consume(QuotaBucket.image, now);

    expect(state.canAcquireFor(QuotaBucket.random), isFalse);
    expect(state.canAcquireFor(QuotaBucket.image), isTrue);

    final recovered = state.pruned(now.add(const Duration(seconds: 301)));
    expect(recovered.canAcquireFor(QuotaBucket.random), isTrue);
    expect(recovered.usedFor(QuotaBucket.random), 0);
    expect(recovered.usedFor(QuotaBucket.image), 0);
  });

  test('server lockout is tracked per bucket', () {
    final now = DateTime.now();
    final state = QuotaState.initial().startServerLockout(
      QuotaBucket.image,
      now.add(const Duration(minutes: 30)),
    );

    expect(state.isServerLockedFor(QuotaBucket.random), isFalse);
    expect(state.isServerLockedFor(QuotaBucket.image), isTrue);
    expect(state.anyServerLocked, isTrue);
    expect(state.longestServerLockedBucket, QuotaBucket.image);
  });
}
