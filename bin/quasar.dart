import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dart_nats/dart_nats.dart';
import 'package:pedantic/pedantic.dart';
import 'package:uuid/uuid.dart';

import 'error_code.dart' as error_code;

class Parameters {
  final String? _return_addr;
  final Map<String, dynamic> _data;

  Parameters(this._return_addr, this._data);

  Map<String, dynamic> get data {
    return _data;
  }

  Map<String, dynamic> toJson() => {'return_addr': _return_addr, 'data': _data};

  Parameters.fromJson(Map<String, dynamic> json)
      : _return_addr = json['return_addr'],
        _data = json['data'];
}

class JSON_RPC {
  final String _jsonrpc = '2.0';
  final String _method;
  final int _id;
  final Parameters _params;

  JSON_RPC(this._method, this._id, this._params);

  Map<String, dynamic> toJson() => {
        'jsonrpc': _jsonrpc,
        'method': _method,
        'params': _params.toJson(),
        'id': _id
      };

  JSON_RPC.fromJson(Map<String, dynamic> json)
      : _id = json['id'],
        _method = json['method'],
        _params = Parameters.fromJson(json['params']);
}

class JSON_RPC_Ret {
  final String _jsonrpc = '2.0';
  final dynamic _result;
  final int _id;

  JSON_RPC_Ret(this._result, this._id);

  Map<String, dynamic> toJson() =>
      {'jsonrpc': _jsonrpc, 'result': _result, 'id': _id};

  JSON_RPC_Ret.fromJson(Map<String, dynamic> json)
      : _id = json['id'],
        _result = json['result'];
}

class JSON_RPC_Err {
  final String _jsonrpc = '2.0';
  final dynamic _error;
  final int? _id;

  JSON_RPC_Err(this._error, this._id);

  Map<String, dynamic> toJson() =>
      {'jsonrpc': _jsonrpc, 'error': _error, 'id': _id};

  JSON_RPC_Err.fromJson(Map<String, dynamic> json)
      : _id = json['id'],
        _error = json['error'];
}

class Quasar {
  Client client = Client();
  late String identifier;

  Future close() async {
    return client.close();
  }
}

class QuasarServer extends Quasar {
  Map<String, Function> methods = {};
  late Subscription<dynamic> sub;

  late String prefix;

  bool _methodFromSubject = false;
  bool _useSegments = false;

  bool get getMethodFromSubject => _methodFromSubject;

  set setMethodFromSubject(bool methodFromSubject) {
    _methodFromSubject = methodFromSubject;
    var _prefixes = prefix.split('.');

    if (methodFromSubject) {
      if (_prefixes[_prefixes.length - 1] != '>') {
        _prefixes.add('>');
      }
    } else {
      if (_prefixes[_prefixes.length - 1] == '>') {
        _prefixes[_prefixes.length - 1] = '';
      }
    }

    prefix = _prefixes.join('.');
    super.client.unSub(sub);
    sub = super.client.sub(prefix);

    unawaited(sub.stream.forEach(_gen_resp));
  }

  bool get getUseSegments => _useSegments;

  set setUseSegments(useSegments) {
    _useSegments = useSegments;
    var _prefixes = prefix.split('.');

    if (useSegments) {
      if (_prefixes[_prefixes.length - 1] != '>') {
        _prefixes.add('>');
      }
    } else {
      if (_prefixes[_prefixes.length - 1] == '>') {
        _prefixes[_prefixes.length - 1] = '';
      }
    }

    prefix = _prefixes.join('.');
    super.client.unSub(sub);
    sub = super.client.sub(prefix);

    unawaited(sub.stream.forEach(_gen_resp));
  }

  QuasarServer(String nats_server_address, name) {
    prefix = name;
    super.identifier = name;

    super.client.connect(Uri.parse(nats_server_address));
    sub = super.client.sub(prefix);

    unawaited(sub.stream.forEach(_gen_resp));
  }

  void registerMethod(String methodName, Function method) {
    methods[methodName] = method;
  }

  String transformMessage(Message rawMsg) {
    var subject = rawMsg.subject;

    var transformedMsg = jsonDecode(rawMsg.string);

    var _prefixes = subject!.replaceFirst(super.identifier, '');
    if (_methodFromSubject) {
      transformedMsg['method'] = _prefixes.split('.')[0];
    }

    if (_useSegments) {
      var idx = 0;
      if (_methodFromSubject) {
        idx++;
      }

      transformedMsg['params']['data']['segments'] =
          _prefixes.split('.').getRange(idx, _prefixes.split('.').length);
    }
    return jsonEncode(transformedMsg);
  }

  void _gen_resp(Message event) async {
    final jsonRPC;

    var msg = transformMessage(event);

    try {
      jsonRPC = JSON_RPC.fromJson(jsonDecode(msg));
    } on FormatException {
      // CAN NOT RETURN AN ERROR BECAUSE THE RETURN ADDRESS WAS IN THE JSON
      return null;
    } catch (e) {
      // JSON CAN BE DECODED BUT CANT FIT TO THE JSON_RPC CLASS
      try {
        var jsonRPC = jsonDecode(msg);

        if (jsonRPC['params']['return_addr'] != null) {
          var jsonRPC_err = JSON_RPC_Err({
            'code': error_code.INVALID_REQUEST,
            'message': error_code.name(error_code.INVALID_REQUEST)
          }, jsonRPC['id'].asNum);

          unawaited(client.pubString(
              jsonRPC._params._return_addr!, jsonEncode(jsonRPC_err)));
        }
        // ignore: empty_catches
      } catch (e) {}

      return null;
    }

    if (!methods.containsKey(jsonRPC._method)) {
      var jsonRPC_err = JSON_RPC_Err({
        'code': error_code.METHOD_NOT_FOUND,
        'message': error_code.name(error_code.METHOD_NOT_FOUND)
      }, jsonRPC['id'].asNum);

      unawaited(client.pubString(
          jsonRPC._params._return_addr!, jsonEncode(jsonRPC_err)));
    }

    var result;
    if (jsonRPC._params._data.isEmpty) {
      result = methods[jsonRPC._method]!();
    } else {
      result = methods[jsonRPC._method]!(jsonRPC._params);
    }

    result = result.toString();

    var jsonRPC_ret = JSON_RPC_Ret(result, jsonRPC._id);

    if (jsonRPC._params._return_addr != null) {
      unawaited(client.pubString(
          jsonRPC._params._return_addr!, jsonEncode(jsonRPC_ret)));
    }
  }
}

class QuasarClient extends Quasar {
  final String nats_addr, server_addr;
  final uuid = Uuid();

  QuasarClient(this.nats_addr, this.server_addr);

  Future listen() {
    return super.client.connect(Uri.parse(nats_addr));
  }

  void sendNotification(String method,
      [Map<String, dynamic> parameters = const {}]) {
    var params = Parameters(null, parameters);
    var jsonRPC = JSON_RPC(method, Random().nextInt(100), params);

    unawaited(client.pubString(server_addr, jsonEncode(jsonRPC)));
  }

  Future sendRequest(String method,
      [Map<String, dynamic> parameters = const {}]) async {
    var req_id = uuid.v4();
    var sub = super.client.sub(req_id);
    var _completer = Completer();

    var params = Parameters(req_id, parameters);
    var jsonRPC = JSON_RPC(method, Random().nextInt(100), params);

    await client.pubString(server_addr, jsonEncode(jsonRPC));
    _processReq(sub.stream.first, _completer);

    return _completer.future;
  }

  void _processReq(Future<Message<dynamic>> msg, Completer _completer) async {
    var returnedMsg = await msg;
    var jsonRPC_Ret = jsonDecode(returnedMsg.string);

    if ((jsonRPC_Ret as Map).containsKey('error')) {
      _completer.completeError(jsonRPC_Ret['error']['code'] +
          ': ' +
          jsonRPC_Ret['error']['message']);

      return null;
    }
    _completer.complete(jsonRPC_Ret['result']);
  }
}

class QuasarPeer implements QuasarServer, QuasarClient {
  late QuasarClient _client;
  late QuasarServer _server;

  late String _peerName, _remotePeerName, _nats_addr;

  @override
  Map<String, Function> methods = {};

  QuasarPeer(String peerName, remotePeerName, nats_addr) {
    _peerName = peerName;
    _remotePeerName = remotePeerName;
    _nats_addr = nats_addr;

    _server = QuasarServer(nats_addr, _peerName);
    _client = QuasarClient(nats_addr, _remotePeerName);
  }

  @override
  Future listen() async {
    return _client.listen();
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
    _client.sendNotification(method);
  }

  @override
  Future sendRequest(String method,
      [Map<String, dynamic> parameters = const {}]) {
    return _client.sendRequest(method, parameters);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main(List<String> arguments) async {
  var server = QuasarServer('nats://127.0.0.1:4222', 'my-test-server-1');

  var i = 5;
  // ADD A METHOD TO SERVER
  server.registerMethod('count', () {
    return i++;
  });

  server.registerMethod('echo', (Parameters params) {
    return params.data['message'];
  });

  var client = QuasarClient('nats://127.0.0.1:4222', 'my-test-server-1');
  await client.listen();

  // SEND REQUEST TO SERVER
  client.sendNotification('count');
  client.sendNotification('count');
  client.sendNotification('count');
  client.sendNotification('count');

  var count = await client.sendRequest('count');
  // count = count.string;
  print('Count is $count');

  var echo = await client.sendRequest('echo', {'message': 'hello'});
  // echo = echo.string;
  print('Echo says $echo');

  await server.close();
  await client.close();

  var peer1_name = 'my-peer-1';
  var peer2_name = 'my-peer-2';

  var peer1 = QuasarPeer(peer1_name, peer2_name, 'nats://127.0.0.1:4222');
  var peer2 = QuasarPeer(peer2_name, peer1_name, 'nats://127.0.0.1:4222');

  await peer1.listen();
  await peer2.listen();

  peer1.registerMethod('name', () => 'peer 1');

  peer2.registerMethod('time', () => DateTime.now().toString());

  var time = await peer1.sendRequest('time');
  print('Peer 2 - time $time');

  var name = await peer2.sendRequest('name');
  print('Peer 1 - name $name');

  await peer1.close();
  await peer2.close();

  // var client = Client();
  // await client.connect(Uri.parse('nats://demo.nats.io:4222'));

  // var sub = client.sub('sub1');
  // sub.stream.forEach((e) async => print(e.string));

  // await client.pubString('sub1', 'my msg');
  // await client.pubString('sub1', 'my msg 2');

  // // await for (final line
  // //     in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
  // //   unawaited(client.pubString('sub1', line));
  // // }

  // var list = List.generate(1000, (index) => index);
  // for (final i in list) {
  //   unawaited(client.pubString('sub1', i.toString()));
  // }
  // // var msg = await sub.stream.first;

  // // print(msg.string);

  // // msg = await sub.stream.first;
  // // print(msg.string);

  // client.unSub(sub);
  // await client.close();
}
