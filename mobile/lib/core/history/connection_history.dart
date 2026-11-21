enum HistoryKind {
  paired('Paired'),
  connected('Connected'),
  lost('Connection lost'),
  disconnected('Disconnected'),
  failed('Could not connect'),
  forgotten('Removed');

  const HistoryKind(this.label);
  final String label;
}

class HistoryEntry {
  const HistoryEntry({required this.atMs, required this.kind, required this.device, this.detail});
  /// Milliseconds since the epoch.
  final int atMs;
  final HistoryKind kind;
  final String device;
  final String? detail;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(atMs);

  Map<String, dynamic> toJson() => {'t': atMs, 'k': kind.name, 'd': device, if (detail != null) 'x': detail};

  static HistoryEntry? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final t = json['t'], d = json['d'];
    final kind = HistoryKind.values.where((k) => k.name == json['k']);
    if (t is! int || d is! String || kind.isEmpty) return null;
    return HistoryEntry(
      atMs: t,
      kind: kind.first,
      device: d.length > 64 ? d.substring(0, 64) : d,
      detail: json['x'] is String ? json['x'] as String : null,
    );
  }
}

/// Newest-first, capped log of connection events. Immutable.
class ConnectionHistory {
  const ConnectionHistory([this.entries = const []]);
  final List<HistoryEntry> entries;

  static const limit = 60;

  ConnectionHistory add(HistoryEntry e) => ConnectionHistory([e, ...entries].take(limit).toList());

  List<Map<String, dynamic>> toJson() => [for (final e in entries) e.toJson()];

  /// Never throws; bad entries are skipped and the result is sorted newest first and capped.
  static ConnectionHistory fromJson(Object? json) {
    if (json is! List) return const ConnectionHistory();
    final list = <HistoryEntry>[];
    for (final raw in json) {
      final e = HistoryEntry.tryFromJson(raw);
      if (e != null) list.add(e);
    }
    list.sort((a, b) => b.atMs.compareTo(a.atMs));
    return ConnectionHistory(list.take(limit).toList());
  }
}
