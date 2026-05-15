const _unset = Object();

enum QuotaBucket {
  random('随机/元数据'),
  image('图片预览');

  const QuotaBucket(this.label);

  final String label;
}

class QuotaWindowState {
  const QuotaWindowState({
    required this.limit,
    required this.window,
    required this.quotaEvents,
    this.serverLockoutUntil,
  });

  final int limit;
  final Duration window;
  final List<DateTime> quotaEvents;
  final DateTime? serverLockoutUntil;

  int get used => _activeEvents(DateTime.now()).length;

  int get remaining {
    final value = limit - used;
    if (value < 0) {
      return 0;
    }
    if (value > limit) {
      return limit;
    }
    return value;
  }

  double get progress => used / limit;

  bool get isServerLocked {
    final until = serverLockoutUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  bool get canAcquire => !isServerLocked && remaining > 0;

  Duration get serverLockoutRemaining {
    final until = serverLockoutUntil;
    if (until == null) {
      return Duration.zero;
    }
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return remaining;
  }

  Duration? get timeUntilNextAvailable {
    final now = DateTime.now();
    final active = _activeEvents(now);
    if (active.length < limit) {
      return null;
    }
    active.sort();
    final unlockAt = active.first.add(window);
    final remaining = unlockAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  QuotaWindowState consume([DateTime? at]) {
    final now = at ?? DateTime.now();
    final current = pruned(now);
    return current.copyWith(
      quotaEvents: [...current.quotaEvents, now],
    );
  }

  QuotaWindowState pruned([DateTime? at]) {
    final now = at ?? DateTime.now();
    final active = _activeEvents(now);
    final lockout =
        serverLockoutUntil != null && now.isAfter(serverLockoutUntil!)
            ? null
            : serverLockoutUntil;
    return copyWith(
      quotaEvents: active,
      serverLockoutUntil: lockout,
    );
  }

  List<DateTime> _activeEvents(DateTime now) {
    final earliest = now.subtract(window);
    return quotaEvents.where((event) => event.isAfter(earliest)).toList();
  }

  QuotaWindowState copyWith({
    int? limit,
    Duration? window,
    List<DateTime>? quotaEvents,
    Object? serverLockoutUntil = _unset,
  }) {
    return QuotaWindowState(
      limit: limit ?? this.limit,
      window: window ?? this.window,
      quotaEvents: quotaEvents ?? this.quotaEvents,
      serverLockoutUntil: identical(serverLockoutUntil, _unset)
          ? this.serverLockoutUntil
          : serverLockoutUntil as DateTime?,
    );
  }
}

class QuotaState {
  const QuotaState({
    required this.random,
    required this.image,
  });

  factory QuotaState.initial() {
    return const QuotaState(
      random: QuotaWindowState(
        limit: 80,
        window: Duration(seconds: 300),
        quotaEvents: [],
      ),
      image: QuotaWindowState(
        limit: 50,
        window: Duration(seconds: 300),
        quotaEvents: [],
      ),
    );
  }

  final QuotaWindowState random;
  final QuotaWindowState image;

  QuotaWindowState bucket(QuotaBucket bucket) {
    return switch (bucket) {
      QuotaBucket.random => random,
      QuotaBucket.image => image,
    };
  }

  int usedFor(QuotaBucket bucket) => this.bucket(bucket).used;

  int remainingFor(QuotaBucket bucket) => this.bucket(bucket).remaining;

  double progressFor(QuotaBucket bucket) => this.bucket(bucket).progress;

  bool isServerLockedFor(QuotaBucket bucket) {
    return this.bucket(bucket).isServerLocked;
  }

  bool canAcquireFor(QuotaBucket bucket) {
    return this.bucket(bucket).canAcquire;
  }

  Duration serverLockoutRemainingFor(QuotaBucket bucket) {
    return this.bucket(bucket).serverLockoutRemaining;
  }

  Duration? timeUntilNextAvailableFor(QuotaBucket bucket) {
    return this.bucket(bucket).timeUntilNextAvailable;
  }

  bool get anyServerLocked {
    return random.isServerLocked || image.isServerLocked;
  }

  Duration get longestServerLockoutRemaining {
    final randomRemaining = random.serverLockoutRemaining;
    final imageRemaining = image.serverLockoutRemaining;
    return randomRemaining > imageRemaining ? randomRemaining : imageRemaining;
  }

  QuotaBucket? get longestServerLockedBucket {
    if (!anyServerLocked) {
      return null;
    }
    final randomRemaining = random.serverLockoutRemaining;
    final imageRemaining = image.serverLockoutRemaining;
    return randomRemaining >= imageRemaining
        ? QuotaBucket.random
        : QuotaBucket.image;
  }

  QuotaBucket? get mostLimitedBucket {
    final locked = longestServerLockedBucket;
    if (locked != null) {
      return locked;
    }
    if (random.remaining == 0 && image.remaining == 0) {
      return random.timeUntilNextAvailable! >= image.timeUntilNextAvailable!
          ? QuotaBucket.random
          : QuotaBucket.image;
    }
    if (random.remaining == 0) {
      return QuotaBucket.random;
    }
    if (image.remaining == 0) {
      return QuotaBucket.image;
    }
    return random.progress >= image.progress ? QuotaBucket.random : QuotaBucket.image;
  }

  QuotaState consume(QuotaBucket bucket, [DateTime? at]) {
    return switch (bucket) {
      QuotaBucket.random => copyWith(random: random.consume(at)),
      QuotaBucket.image => copyWith(image: image.consume(at)),
    };
  }

  QuotaState startServerLockout(QuotaBucket bucket, DateTime until) {
    return switch (bucket) {
      QuotaBucket.random => copyWith(
          random: random.pruned().copyWith(serverLockoutUntil: until),
        ),
      QuotaBucket.image => copyWith(
          image: image.pruned().copyWith(serverLockoutUntil: until),
        ),
    };
  }

  QuotaState pruned([DateTime? at]) {
    return copyWith(
      random: random.pruned(at),
      image: image.pruned(at),
    );
  }

  QuotaState copyWith({
    QuotaWindowState? random,
    QuotaWindowState? image,
  }) {
    return QuotaState(
      random: random ?? this.random,
      image: image ?? this.image,
    );
  }

  // Backward-compatible random-bucket helpers used by the main browsing flow.
  int get limit => random.limit;
  int get used => random.used;
  int get remaining => random.remaining;
  double get progress => random.progress;
  bool get isServerLocked => random.isServerLocked;
  bool get canAcquire => random.canAcquire;
  Duration get serverLockoutRemaining => random.serverLockoutRemaining;
  Duration? get timeUntilNextAvailable => random.timeUntilNextAvailable;
}
