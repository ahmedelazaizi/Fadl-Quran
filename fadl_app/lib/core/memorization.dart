import 'dart:math' as math;

class MemorizationSettings {
  const MemorizationSettings({
    this.ayahRepeats = 1,
    this.rangeStart,
    this.rangeEnd,
    this.rangeRepeats = 1,
    this.pauseMode = 0,
    this.speed = 1.0,
  });

  // Zero repeats means unlimited; pause modes: 0 off, 1 equal, 2 double, 3/5/10 seconds.
  final int ayahRepeats;
  final int? rangeStart;
  final int? rangeEnd;
  final int rangeRepeats;
  final int pauseMode;
  final double speed;
  bool get hasRange => rangeStart != null && rangeEnd != null;

  MemorizationSettings copyWith({
    int? ayahRepeats,
    int? rangeStart,
    int? rangeEnd,
    int? rangeRepeats,
    int? pauseMode,
    double? speed,
    bool clearRange = false,
  }) => MemorizationSettings(
    ayahRepeats: ayahRepeats ?? this.ayahRepeats,
    rangeStart: clearRange ? null : rangeStart ?? this.rangeStart,
    rangeEnd: clearRange ? null : rangeEnd ?? this.rangeEnd,
    rangeRepeats: rangeRepeats ?? this.rangeRepeats,
    pauseMode: pauseMode ?? this.pauseMode,
    speed: speed ?? this.speed,
  );

  Map<String, dynamic> toJson() => {
    'ayahRepeats': ayahRepeats,
    'rangeStart': rangeStart,
    'rangeEnd': rangeEnd,
    'rangeRepeats': rangeRepeats,
    'pauseMode': pauseMode,
    'speed': speed,
  };

  factory MemorizationSettings.fromJson(Map<String, dynamic> json) =>
      MemorizationSettings(
        ayahRepeats: (json['ayahRepeats'] as int?) ?? 1,
        rangeStart: json['rangeStart'] as int?,
        rangeEnd: json['rangeEnd'] as int?,
        rangeRepeats: (json['rangeRepeats'] as int?) ?? 1,
        pauseMode: (json['pauseMode'] as int?) ?? 0,
        speed: ((json['speed'] as num?) ?? 1).toDouble(),
      );

  Duration pauseFor(Duration ayahDuration) => switch (pauseMode) {
    1 => ayahDuration,
    2 => ayahDuration * 2,
    3 || 5 || 10 => Duration(seconds: pauseMode),
    _ => Duration.zero,
  };
}

enum MemorizationMove { replay, advance, rangeStart, stop }

class MemorizationDecision {
  const MemorizationDecision(this.move, this.pause);
  final MemorizationMove move;
  final Duration pause;
}

/// Counts are one-based completed plays of the current ayah and range.
MemorizationDecision nextMemorizationAction({
  required MemorizationSettings settings,
  required int ayah,
  required int ayahCount,
  required int ayahPlay,
  required int rangePlay,
  required Duration ayahDuration,
}) {
  final pause = settings.pauseFor(ayahDuration);
  if (settings.ayahRepeats == 0 || ayahPlay < settings.ayahRepeats) {
    return MemorizationDecision(MemorizationMove.replay, pause);
  }
  final end = settings.hasRange
      ? math.min(settings.rangeEnd!, ayahCount)
      : ayahCount;
  if (ayah < end) return MemorizationDecision(MemorizationMove.advance, pause);
  if (settings.hasRange) {
    if (settings.rangeRepeats == 0 || rangePlay < settings.rangeRepeats) {
      return MemorizationDecision(MemorizationMove.rangeStart, pause);
    }
    return MemorizationDecision(MemorizationMove.stop, pause);
  }
  return MemorizationDecision(MemorizationMove.stop, pause);
}
