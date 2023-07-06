import 'dart:async';
import 'dart:convert';
import 'package:pedantic/pedantic.dart';

import 'package:dart_nats/dart_nats.dart';

import 'client.dart';
import 'server.dart';

class QuasarPeer implements QuasarServer, QuasarClient {
  late QuasarClient _client;
  late QuasarServer _server;

  late String _peerName,
      _remotePeerName,
      _nats_addr,
      _rendezvous,
      connStatus = 'not connected';

  late Subscription _rendezvousSub;

  Timer? timer;

  @override
  Map<String, Function> methods = {};

  Client get client => _client.client;

  QuasarPeer(String peerName, rendezvous, nats_addr) {
    _peerName = peerName;
    _rendezvous = rendezvous;
    _nats_addr = nats_addr;

    _server = QuasarServer(nats_addr, _peerName);
    // _client = QuasarClient(nats_addr, _remotePeerName);
  }

  @override
  Future listen() async {
    var _completer = Completer();

    await _server.client.waitUntilConnected();

    _server.registerMethod('hello', (params) {
      if (connStatus == 'not connected') {
        connStatus = 'connecting';
        connectToPeer(params.data.remoteAddr.toString(), _completer);
      }
      return 'acknowledged';
    });

    _rendezvousSub = _server.client.sub(_rendezvous);

    unawaited(_rendezvousSub.stream.forEach((element) {
      var msg = jsonDecode(element.string);
      connectToPeer(msg['params']['data']['remoteAddr'].toString(), _completer);
    }));

    broadcastSelf();

    return _completer.future;
  }

  void connectToPeer(String newFoundPeer, Completer _completer) async {
    if (newFoundPeer == _peerName) {
      return;
    }
    _remotePeerName = newFoundPeer;
    _client = QuasarClient(_nats_addr, _remotePeerName);
    await _client.listen();

    // await _client.sendRequest('hello', {'remoteAddr': _peerName});
    _server.client.unSub(_rendezvousSub);

    timer!.cancel();

    _completer.complete();
  }

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

  @override
  Future close() async {
    await _client.close();
    await _server.close();
  }

  @override
  void registerMethod(String methodName, Function method) {
    _server.registerMethod(methodName, method);
  }

  @override
  void sendNotification(String method,
      [Map<String, dynamic> parameters = const {}]) {
    _client.sendNotification(method, parameters);
  }

  @override
  Future sendRequest(String method,
      [Map<String, dynamic> parameters = const {}]) {
    return _client.sendRequest(method, parameters);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
