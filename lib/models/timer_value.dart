import 'dart:convert';

class TimerValue {
  final int durationSec; // target duration
  final int elapsedSec; // baseline elapsed when not running
  final bool running;
  final String? startedAtIso; // when running, the wall time it was started/resumed

  const TimerValue({
    required this.durationSec,
    this.elapsedSec = 0,
    this.running = false,
    this.startedAtIso,
  });

  int get remainingSec => (durationSec - effectiveElapsed(DateTime.now())).clamp(0, durationSec);
  double get progress => durationSec == 0 ? 0 : (effectiveElapsed(DateTime.now()) / durationSec).clamp(0.0, 1.0);
  bool get isComplete => effectiveElapsed(DateTime.now()) >= durationSec && durationSec > 0;

  int effectiveElapsed(DateTime now) {
    if (!running || startedAtIso == null) return elapsedSec;
    final startedAt = DateTime.tryParse(startedAtIso!);
    if (startedAt == null) return elapsedSec;
    final delta = now.difference(startedAt).inSeconds;
    return (elapsedSec + delta).clamp(0, durationSec);
  }

  TimerValue copyWith({int? durationSec, int? elapsedSec, bool? running, String? startedAtIso, bool clearStartedAt = false}) =>
      TimerValue(
        durationSec: durationSec ?? this.durationSec,
        elapsedSec: elapsedSec ?? this.elapsedSec,
        running: running ?? this.running,
        startedAtIso: clearStartedAt ? null : (startedAtIso ?? this.startedAtIso),
      );

  // Start / resume: set running true, record now
  TimerValue started(DateTime now) => copyWith(running: true, startedAtIso: now.toIso8601String());

  // Pause: freeze elapsed
  TimerValue paused(DateTime now) {
    final eff = effectiveElapsed(now);
    return TimerValue(durationSec: durationSec, elapsedSec: eff, running: false, startedAtIso: null);
  }

  // Stop: reset to 0, not running
  TimerValue stopped() => TimerValue(durationSec: durationSec, elapsedSec: 0, running: false, startedAtIso: null);

  // Restart: reset elapsed to 0 and start again
  TimerValue restarted(DateTime now) => TimerValue(durationSec: durationSec, elapsedSec: 0, running: true, startedAtIso: now.toIso8601String());

  Map<String, dynamic> toJson() => {
        'durationSec': durationSec,
        'elapsedSec': elapsedSec,
        'running': running,
        'startedAtIso': startedAtIso,
      };

  factory TimerValue.fromJson(Map<String, dynamic> j) => TimerValue(
        durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
        elapsedSec: (j['elapsedSec'] as num?)?.toInt() ?? 0,
        running: j['running'] as bool? ?? false,
        startedAtIso: j['startedAtIso'] as String?,
      );

  static TimerValue? tryParse(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        return TimerValue.fromJson(m);
      } catch (_) {
        final sec = parseDurationToSec(raw);
        if (sec > 0) return TimerValue(durationSec: sec);
        return null;
      }
    }
    if (raw is Map) return TimerValue.fromJson(Map<String, dynamic>.from(raw));
    return null;
  }

  String toJsonString() => jsonEncode(toJson());

  // Human helpers
  static int parseDurationToSec(String input) {
    // supports "4h", "30min", "1h 20m", "90m", "45", "2:30", "1h 20m / 4h" -> takes first part
    var s = input.trim().toLowerCase();
    if (s.isEmpty) return 0;
    // if contains "/" take left side as elapsed? Actually for duration we take whole
    if (s.contains('/')) s = s.split('/').last.trim();
    int total = 0;
    // handle colon "2:30" => 2h30m or 2m30s? treat as h:m
    if (RegExp(r'^\d+:\d+').hasMatch(s)) {
      final parts = s.split(':');
      if (parts.length == 2) {
        total += (int.tryParse(parts[0]) ?? 0) * 3600;
        total += (int.tryParse(parts[1]) ?? 0) * 60;
        return total;
      }
    }
    final re = RegExp(r'(\d+(?:\.\d+)?)\s*(h|hour|hours|hr|m|min|mins|minutes|s|sec|seconds)?');
    for (final m in re.allMatches(s)) {
      final v = double.tryParse(m.group(1)!) ?? 0;
      final unit = m.group(2) ?? 'm';
      if (unit.startsWith('h')) total += (v * 3600).round();
      else if (unit.startsWith('s')) total += v.round();
      else total += (v * 60).round(); // default min
    }
    if (total == 0) {
      final n = int.tryParse(s);
      if (n != null) total = n * 60;
    }
    return total;
  }

  static String formatSec(int sec) {
    if (sec <= 0) return '0m';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    if (m > 0 && s > 0) return '${m}m ${s}s';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  String get displayElapsed => formatSec(effectiveElapsed(DateTime.now()));
  String get displayDuration => formatSec(durationSec);
  String get displayRemaining => formatSec(remainingSec);
  String get compactLabel => '${formatSec(effectiveElapsed(DateTime.now()))} / ${formatSec(durationSec)}';
}
