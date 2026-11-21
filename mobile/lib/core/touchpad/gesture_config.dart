import '../shortcuts/system_actions.dart';

enum SwipeDirection { up, down, left, right }

/// Every gesture the engine recognises. Each one has a card on the gesture settings screen.
enum GestureId {
  oneFingerMove,
  oneFingerTap,
  doubleTap,
  twoFingerTap,
  scrollVertical,
  scrollHorizontal,
  longPress,
  threeUp,
  threeDown,
  threeLeft,
  threeRight,
  fourUp,
  fourDown,
  fourLeft,
  fourRight;

  int get fingers => switch (this) {
        oneFingerMove || oneFingerTap || doubleTap || longPress => 1,
        twoFingerTap || scrollVertical || scrollHorizontal => 2,
        threeUp || threeDown || threeLeft || threeRight => 3,
        fourUp || fourDown || fourLeft || fourRight => 4,
      };

  bool get isSwipe => fingers >= 3;

  SwipeDirection? get direction => switch (this) {
        threeUp || fourUp => SwipeDirection.up,
        threeDown || fourDown => SwipeDirection.down,
        threeLeft || fourLeft => SwipeDirection.left,
        threeRight || fourRight => SwipeDirection.right,
        _ => null,
      };

  static GestureId? swipe(int fingers, SwipeDirection d) {
    for (final g in values) {
      if (g.isSwipe && g.fingers == fingers && g.direction == d) return g;
    }
    return null;
  }
}

/// What a swipe does: a macOS system action or one of the user's shortcuts. No action = the gesture does nothing.
sealed class GestureAction {
  const GestureAction();
  Map<String, dynamic> toJson();

  /// Null for anything malformed (including unknown system actions).
  static GestureAction? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty || id.length > 80) return null;
    switch (json['t']) {
      case 'sys':
        return SystemActionIds.isValid(id) ? SystemGestureAction(id) : null;
      case 'shortcut':
        return ShortcutGestureAction(id);
      default:
        return null;
    }
  }
}

class SystemGestureAction extends GestureAction {
  const SystemGestureAction(this.action);
  final String action;
  @override
  Map<String, dynamic> toJson() => {'t': 'sys', 'id': action};
  @override
  bool operator ==(Object other) => other is SystemGestureAction && other.action == action;
  @override
  int get hashCode => Object.hash('sys', action);
}

class ShortcutGestureAction extends GestureAction {
  const ShortcutGestureAction(this.shortcutId);
  final String shortcutId;
  @override
  Map<String, dynamic> toJson() => {'t': 'shortcut', 'id': shortcutId};
  @override
  bool operator ==(Object other) => other is ShortcutGestureAction && other.shortcutId == shortcutId;
  @override
  int get hashCode => Object.hash('shortcut', shortcutId);
}

/// Per-gesture settings. Which fields matter depends on the gesture (see gesture_catalog in the UI).
class GestureSetting {
  const GestureSetting({
    this.enabled = true,
    this.sensitivity = 1.0,
    this.distance = 80,
    this.holdMs = 450,
    this.action,
  });

  final bool enabled;
  /// Multiplier (0.5 - 2.0). Tap gestures: tolerance and timing. Horizontal scroll: speed.
  final double sensitivity;
  /// Swipes: how far the fingers must travel, in logical pixels (30 - 300).
  final double distance;
  /// Long press: how long the finger must rest (200 - 1200 ms).
  final int holdMs;
  final GestureAction? action;

  static const sensitivityRange = (min: 0.5, max: 2.0);
  static const distanceRange = (min: 30.0, max: 300.0);
  static const holdRange = (min: 200, max: 1200);

  GestureSetting copyWith({bool? enabled, double? sensitivity, double? distance, int? holdMs, GestureAction? action, bool clearAction = false}) =>
      GestureSetting(
        enabled: enabled ?? this.enabled,
        sensitivity: sensitivity ?? this.sensitivity,
        distance: distance ?? this.distance,
        holdMs: holdMs ?? this.holdMs,
        action: clearAction ? null : (action ?? this.action),
      );

  Map<String, dynamic> toJson() => {
        'on': enabled, 'sens': sensitivity, 'dist': distance, 'hold': holdMs,
        if (action != null) 'action': action!.toJson(),
      };

  /// Never throws. Out-of-range numbers are clamped; a missing or invalid action stays "no action".
  static GestureSetting fromJson(Object? json, GestureSetting fallback) {
    if (json is! Map<String, dynamic>) return fallback;
    double n(String k, double def, double lo, double hi) {
      final v = json[k];
      return v is num && v.isFinite ? v.toDouble().clamp(lo, hi).toDouble() : def;
    }

    final hold = json['hold'];
    return GestureSetting(
      enabled: json['on'] is bool ? json['on'] as bool : fallback.enabled,
      sensitivity: n('sens', fallback.sensitivity, sensitivityRange.min, sensitivityRange.max),
      distance: n('dist', fallback.distance, distanceRange.min, distanceRange.max),
      holdMs: hold is int ? hold.clamp(holdRange.min, holdRange.max).toInt() : fallback.holdMs,
      action: json.containsKey('action') ? GestureAction.fromJson(json['action']) : null,
    );
  }
}

class GestureConfig {
  GestureConfig._(this._m);

  /// The mapping the app ships with: three fingers = Mission Control / App Expos\u00e9 / previous / next desktop.
  factory GestureConfig.defaults() => GestureConfig._({for (final id in GestureId.values) id: defaultFor(id)});

  final Map<GestureId, GestureSetting> _m;

  static GestureSetting defaultFor(GestureId id) => switch (id) {
        GestureId.threeUp => const GestureSetting(distance: 80, action: SystemGestureAction(SystemActionIds.missionControl)),
        GestureId.threeDown => const GestureSetting(distance: 80, action: SystemGestureAction(SystemActionIds.appExpose)),
        GestureId.threeLeft => const GestureSetting(distance: 80, action: SystemGestureAction(SystemActionIds.desktopLeft)),
        GestureId.threeRight => const GestureSetting(distance: 80, action: SystemGestureAction(SystemActionIds.desktopRight)),
        GestureId.fourUp => const GestureSetting(distance: 70, action: SystemGestureAction(SystemActionIds.showDesktop)),
        GestureId.fourDown => const GestureSetting(distance: 70),
        GestureId.fourLeft => const GestureSetting(distance: 70, action: ShortcutGestureAction('preset.app_switcher')),
        GestureId.fourRight => const GestureSetting(distance: 70),
        GestureId.longPress => const GestureSetting(holdMs: 450),
        _ => const GestureSetting(),
      };

  GestureSetting operator [](GestureId id) => _m[id]!;

  GestureConfig with_(GestureId id, GestureSetting s) => GestureConfig._({..._m, id: s});

  /// True if any swipe with exactly [fingers] fingers is enabled.
  bool anyEnabledFor(int fingers) => GestureId.values.any((g) => g.isSwipe && g.fingers == fingers && _m[g]!.enabled);

  Map<String, dynamic> toJson() => {for (final e in _m.entries) e.key.name: e.value.toJson()};

  /// Never throws: unknown ids are ignored, missing gestures get their defaults.
  static GestureConfig fromJson(Object? json) {
    final out = <GestureId, GestureSetting>{};
    final map = json is Map<String, dynamic> ? json : const <String, dynamic>{};
    for (final id in GestureId.values) {
      out[id] = GestureSetting.fromJson(map[id.name], defaultFor(id));
    }
    return GestureConfig._(out);
  }
}
