import 'dart:async';
import 'dart:io';

/// One network interface a download can send its connections through.
class NetworkPath {
  const NetworkPath(this.name, this.address);

  /// Interface name as the OS reports it (`en0`, `Wi-Fi`, `wlan0`, ...).
  final String name;

  /// Local address connections are bound to.
  final InternetAddress address;

  @override
  String toString() => '$name (${address.address})';
}

/// Interfaces that look like real uplinks: no loopback, link-local, VPN,
/// virtual-machine, container or Apple peer-to-peer links.
Future<List<NetworkPath>> findNetworkPaths() async {
  final List<NetworkInterface> interfaces;
  try {
    interfaces = await NetworkInterface.list(
      includeLoopback: false,
      includeLinkLocal: false,
      type: InternetAddressType.IPv4,
    );
  } catch (_) {
    return const [];
  }
  return [
    for (final interface in interfaces)
      if (!_virtual.hasMatch(interface.name) && interface.addresses.isNotEmpty)
        NetworkPath(interface.name, interface.addresses.first),
  ];
}

final _virtual = RegExp(
  r'^(lo|utun|ipsec|ppp|tun|tap|wg|tailscale|zt|awdl|llw|bridge|br-|docker|'
  r'veth|virbr|vboxnet|vmnet|lxc|lxd|anpi|ap\d|gif|stf)|vEthernet|VirtualBox|'
  r'VMware|Loopback',
  caseSensitive: false,
);

/// An [HttpClient] connection factory that pins every socket to [source].
///
/// HttpClient skips its own TLS setup when a factory is installed, so direct
/// `https` connections are secured here. Proxied ones are left plain: the
/// client tunnels through the proxy and does TLS itself.
Future<ConnectionTask<Socket>> Function(Uri, String?, int?) boundConnector(
  InternetAddress source,
) {
  return (uri, proxyHost, proxyPort) async {
    final host = proxyHost ?? uri.host;
    final port = proxyPort ?? uri.port;
    // A socket bound to an IPv4 address can only reach IPv4 peers.
    final targets = await InternetAddress.lookup(host, type: source.type);
    if (targets.isEmpty) {
      throw SocketException('No ${source.type.name} address for $host');
    }
    final task = await Socket.startConnect(
      targets.first,
      port,
      sourceAddress: source,
    );
    if (proxyHost != null || !uri.isScheme('https')) return task;
    return ConnectionTask.fromSocket(
      task.socket.then((socket) => SecureSocket.secure(socket, host: uri.host)),
      task.cancel,
    );
  };
}
