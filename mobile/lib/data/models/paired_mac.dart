class PairedMac {
  PairedMac({
    required this.serverId,
    required this.name,
    required this.host,
    required this.port,
    required this.pairedAt,
    required this.lastConnectedAt,
  });

  final String serverId;
  final String name;
  final String host;
  final int port;
  final DateTime pairedAt;
  final DateTime lastConnectedAt;

  PairedMac copyWith({String? host, int? port, DateTime? lastConnectedAt}) => PairedMac(
        serverId: serverId, name: name, host: host ?? this.host, port: port ?? this.port,
        pairedAt: pairedAt, lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      );

  Map<String, dynamic> toJson() => {
        'serverId': serverId, 'name': name, 'host': host, 'port': port,
        'pairedAt': pairedAt.toIso8601String(), 'lastConnectedAt': lastConnectedAt.toIso8601String(),
      };

  /// Returns null for malformed records instead of throwing.
  static PairedMac? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final serverId = json['serverId'], name = json['name'], host = json['host'], port = json['port'];
    final pairedAt = DateTime.tryParse('${json['pairedAt']}');
    final last = DateTime.tryParse('${json['lastConnectedAt']}');
    if (serverId is! String || name is! String || host is! String || port is! int || pairedAt == null || last == null) {
      return null;
    }
    return PairedMac(serverId: serverId, name: name, host: host, port: port, pairedAt: pairedAt, lastConnectedAt: last);
  }
}
