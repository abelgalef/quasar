import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dart_nats/dart_nats.dart';
import 'package:pedantic/pedantic.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

/// A Quasae Client Class that extends the [Quasar] class.
class QuasarClient extends Quasar {
  /// A String identifier for the NATS server and our unique name (prefix) respectively.
  final String nats_addr, server_addr;

  /// Intiate the UUID generator for requests.
  final uuid = Uuid();

  /// Constructor for the [QuasarClient] class.
  ///
  /// @param String `nats_addr` The NATS server address to connect to.
  ///
  /// @param String `server_addr` The unique name of the server or the subject (prefix) to subscribe to.
  QuasarClient(this.nats_addr, this.server_addr);

  /// Returns a future which completes when the [QuasarClient] has connected to the NATS server.
  ///
  /// The Client can not work without this first being invoked.
  Future listen() {
    return super.client.connect(Uri.parse(nats_addr));
  }

  /// Sends a Request and dose not excpect a response, errors from the server are suppressed.
  ///
  /// @param String `method` The method to be invoked on the server.
  ///
  /// @param Map<String, dynamic> `parameters` The parameters to pass to the method.
  void sendNotification(String method,
      [Map<String, dynamic> parameters = const {}]) {
    var params = Parameters(null, parameters);
    var jsonRPC = JSON_RPC(method, Random().nextInt(100), params);

    unawaited(client.pubString(server_addr, jsonEncode(jsonRPC)));
  }

  /// Sends a Request and returns a `Future` that will be completed with the data the method returns.
  ///
  /// @param String `method` The method to be invoked on the server.
  ///
  /// @param Map<String, dynamic> `parameters` The parameters to pass to the method.
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

  /// Processes the response from the server.
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
