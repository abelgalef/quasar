import 'dart:async';
import 'dart:convert';
import 'package:pedantic/pedantic.dart';

import 'package:dart_nats/dart_nats.dart';

import 'client.dart';
import 'server.dart';

/// A Quasar Peer class that implements the [QuasarServer] and [QuasarClient] class.
///
/// This is just a wrapper around the QuasarServer and QuasarClient classes with an auto-discovery system.
class QuasarPeer implements QuasarServer, QuasarClient {
  /// The [QuasarClient] for the class.
  late QuasarClient _client;

  /// The [QuasarServer] for the class.
  late QuasarServer _server;

  /// The unique identifier of this peer.
  late String _peerName,

      /// The unique identifier of the remote peer.
      _remotePeerName,

      /// The NATS server address.
      _nats_addr,

      /// The rendezvous address for the peers.
      _rendezvous,

      /// Current connection status for the peers.
      connStatus = 'not connected';

  /// The subscribtion to the rendezvous subject.
  late Subscription _rendezvousSub;

  /// Periodic Timer for brodacasting this peer.
  Timer? timer;

  /// Override the list of methods from the [QuasarServer].
  @override
  Map<String, Function> methods = {};

  @override
  Client get client => _client.client;

  /// Constructor for the [QuasarPeer] class.
  ///
  /// @param String `peerName` The unique name of the peer or the subject (prefix) to subscribe to.
  ///
  /// @param String `rendezvous` The meeting place for two peers to discover eachother.
  ///
  /// @param String `nats_addr` The NATS server address to connect to.
  QuasarPeer(String peerName, rendezvous, nats_addr) {
    _peerName = peerName;
    _rendezvous = rendezvous;
    _nats_addr = nats_addr;

    _server = QuasarServer(nats_addr, _peerName);
    // _client = QuasarClient(nats_addr, _remotePeerName);
  }

  /// Returns a future which completes when the [QuasarPeer] has connected to another [QuasarPeer].
  ///
  /// The Peer can not work without this first being invoked.
  @override
  Future listen() async {
    var _completer = Completer();

    // Wait untill the we connect to the NATS server.
    await _server.client.waitUntilConnected();

    // Register a hello method for discovering other peers.
    _server.registerMethod('hello', (params) {
      if (connStatus == 'not connected') {
        connStatus = 'connecting';
        connectToPeer(params.data.remoteAddr.toString(), _completer);
      }
      return 'acknowledged';
    });

    // Subscirbe to the rendezvous subject and listen for other peers.
    _rendezvousSub = _server.client.sub(_rendezvous);

    unawaited(_rendezvousSub.stream.forEach((element) {
      var msg = jsonDecode(element.string);
      connectToPeer(msg['params']['data']['remoteAddr'].toString(), _completer);
    }));

    // Start brodcasting self every 2 seconds.
    broadcastSelf();

    return _completer.future;
  }

  /// Connect to the new found peer.
  void connectToPeer(String newFoundPeer, Completer _completer) async {
    if (newFoundPeer == _peerName) {
      // If it is us just return.
      return;
    }

    _remotePeerName = newFoundPeer;

    // Initalize the [QuasarClient] and wait for it to connect to the NATS server.
    _client = QuasarClient(_nats_addr, _remotePeerName);
    await _client.listen();

    // await _client.sendRequest('hello', {'remoteAddr': _peerName});

    // Unsubscribe from the rendezvous point.
    _server.client.unSub(_rendezvousSub);

    // Stop brodcasting our self.
    timer!.cancel();

    _completer.complete();
  }

  /// Starts bordcasting our self every 2 seconds on a pre agreed rendezvous point.
  void broadcastSelf() async {
    timer = Timer.periodic(
        Duration(seconds: 2),
        (Timer t) => _server.client.pubString(
            _rendezvous,
            jsonEncode({
              'jsonrpc': '2.0',
              'method': 'hello',
              'params': {
                'return_addr': null,
                'data': {'remoteAddr': _peerName}
              },
              'id': 1234
            })));
  }

  /// Override both the [QuasarClient] and [QuasarServer] to close thier connections to the NAT server.
  @override
  Future close() async {
    await _client.close();
    await _server.close();
  }

  /// Add a function this peer can invoke.
  ///
  /// @param String `methodName` The name of the method.
  ///
  /// @param Function `method` The function to add.
  @override
  void registerMethod(String methodName, Function method) {
    _server.registerMethod(methodName, method);
  }

  /// Sends a Request and dose not excpect a response, errors from the server are suppressed.
  ///
  /// @param String `method` The method to be invoked on the server.
  ///
  /// @param Map<String, dynamic> `parameters` The parameters to pass to the method.
  @override
  void sendNotification(String method,
      [Map<String, dynamic> parameters = const {}]) {
    _client.sendNotification(method, parameters);
  }

  /// Sends a Request and returns a `Future` that will be completed with the data the method returns.
  ///
  /// @param String `method` The method to be invoked on the server.
  ///
  /// @param Map<String, dynamic> `parameters` The parameters to pass to the method.
  @override
  Future sendRequest(String method,
      [Map<String, dynamic> parameters = const {}]) {
    return _client.sendRequest(method, parameters);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
