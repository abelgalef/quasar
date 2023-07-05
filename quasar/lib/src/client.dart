import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dart_nats/dart_nats.dart';
import 'package:pedantic/pedantic.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

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
    Map<String, dynamic> jsonRPC_Ret = jsonDecode(returnedMsg.string);

    if (jsonRPC_Ret.containsKey('error')) {
      // _completer.completeError(jsonRPC_Ret['error']['code'] +
      //     ': ' +
      //     jsonRPC_Ret['error']['message']);
      _completer.completeError(JSON_RPC_Err.fromJson(jsonRPC_Ret));

      return null;
    }
    _completer.complete(jsonRPC_Ret['result']);
  }
}
