import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkStatus {
  const NetworkStatus({required this.online, required this.signature});
  /// True when on Wi-Fi or Ethernet (the Mac is only reachable on the local network).
  final bool online;
  final String signature;
}

class NetworkMonitorService {
  NetworkMonitorService([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();
  final Connectivity _connectivity;

  Future<NetworkStatus> current() async => _map(await _connectivity.checkConnectivity());

  Stream<NetworkStatus> get changes => _connectivity.onConnectivityChanged
      .map(_map)
      .distinct((a, b) => a.signature == b.signature);

  static NetworkStatus _map(List<ConnectivityResult> results) {
    final names = results.map((r) => r.name).toList()..sort();
    return NetworkStatus(
      online: results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.ethernet),
      signature: names.join(','),
    );
  }
}
