import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/random_image/domain/quota_state.dart';
import 'shared_preferences_provider.dart';

final quotaServiceProvider = Provider<QuotaService>((ref) {
  return QuotaService(ref.watch(sharedPreferencesProvider));
});

final quotaControllerProvider =
    StateNotifierProvider<QuotaController, QuotaState>((ref) {
  final controller = QuotaController(ref.watch(quotaServiceProvider));
  return controller;
});

class QuotaService {
  QuotaService(this._preferences);

  static const _eventsKey = 'nice_view.quota_events';
  static const _serverLockoutKey = 'nice_view.server_lockout_until';
  static const _randomEventsKey = 'nice_view.quota.random_events';
  static const _imageEventsKey = 'nice_view.quota.image_events';
  static const _randomServerLockoutKey =
      'nice_view.quota.random_lockout_until';
  static const _imageServerLockoutKey = 'nice_view.quota.image_lockout_until';
  static const _v2MigratedKey = 'nice_view.quota.v2_migrated';

  final SharedPreferences _preferences;

  QuotaState load() {
    final initial = QuotaState.initial();
    final migrated = _preferences.getBool(_v2MigratedKey) == true;
    final legacyEvents = _loadEvents(_eventsKey);
    final randomEvents = _loadEvents(_randomEventsKey);
    final imageEvents = _loadEvents(_imageEventsKey);
    final legacyLockout = _loadDate(_serverLockoutKey);
    final randomLockout = _loadDate(_randomServerLockoutKey);
    final imageLockout = _loadDate(_imageServerLockoutKey);

    final state = initial
        .copyWith(
          random: initial.random.copyWith(
            quotaEvents: randomEvents.isNotEmpty
                ? randomEvents
                : migrated
                    ? randomEvents
                    : legacyEvents,
            serverLockoutUntil: randomLockout ?? legacyLockout,
          ),
          image: initial.image.copyWith(
            quotaEvents: imageEvents,
            serverLockoutUntil: imageLockout,
          ),
        )
        .pruned();
    if (!migrated) {
      unawaited(save(state));
    }
    return state;
  }

  Future<void> save(QuotaState state) async {
    final pruned = state.pruned();
    await _preferences.setStringList(
      _randomEventsKey,
      pruned.random.quotaEvents
          .map((event) => event.toIso8601String())
          .toList(),
    );
    await _preferences.setStringList(
      _imageEventsKey,
      pruned.image.quotaEvents
          .map((event) => event.toIso8601String())
          .toList(),
    );
    await _saveLockout(_randomServerLockoutKey, pruned.random);
    await _saveLockout(_imageServerLockoutKey, pruned.image);
    await _preferences.setBool(_v2MigratedKey, true);
  }

  List<DateTime> _loadEvents(String key) {
    return (_preferences.getStringList(key) ?? const [])
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList();
  }

  DateTime? _loadDate(String key) {
    final value = _preferences.getString(key);
    return value == null ? null : DateTime.tryParse(value);
  }

  Future<void> _saveLockout(String key, QuotaWindowState bucket) async {
    final until = bucket.serverLockoutUntil;
    if (until == null) {
      await _preferences.remove(key);
    } else {
      await _preferences.setString(key, until.toIso8601String());
    }
  }
}

class QuotaController extends StateNotifier<QuotaState> {
  QuotaController(this._service) : super(_service.load()) {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final QuotaService _service;
  Timer? _ticker;

  Future<bool> tryConsume(QuotaBucket bucket) async {
    final pruned = state.pruned();
    if (!pruned.canAcquireFor(bucket)) {
      state = pruned;
      await _service.save(state);
      return false;
    }

    state = pruned.consume(bucket);
    await _service.save(state);
    return true;
  }

  Future<bool> tryConsumeRemoteRequest() {
    return tryConsume(QuotaBucket.random);
  }

  bool canAcquire(QuotaBucket bucket) {
    return state.pruned().canAcquireFor(bucket);
  }

  Duration? timeUntilNextAvailable(QuotaBucket bucket) {
    return state.pruned().timeUntilNextAvailableFor(bucket);
  }

  Duration serverLockoutRemaining(QuotaBucket bucket) {
    return state.pruned().serverLockoutRemainingFor(bucket);
  }

  Future<void> startServerLockout(QuotaBucket bucket) async {
    state = state.pruned().startServerLockout(
          bucket,
          DateTime.now().add(const Duration(minutes: 30)),
        );
    await _service.save(state);
  }

  Future<void> pruneAndSave() async {
    state = state.pruned();
    await _service.save(state);
  }

  void _tick() {
    final next = state.pruned();
    if (next.random.used != state.random.used ||
        next.image.used != state.image.used ||
        next.random.serverLockoutUntil != state.random.serverLockoutUntil ||
        next.image.serverLockoutUntil != state.image.serverLockoutUntil ||
        next.random.timeUntilNextAvailable !=
            state.random.timeUntilNextAvailable ||
        next.image.timeUntilNextAvailable !=
            state.image.timeUntilNextAvailable) {
      state = next;
      unawaited(_service.save(state));
    } else {
      state = next;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
