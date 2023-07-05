import 'dart:convert';

import 'package:dart_nats/dart_nats.dart';
import 'package:pedantic/pedantic.dart';

import '../error_code.dart' as error_code;
import 'models.dart';

class QuasarServer extends Quasar {
  Map<String, Function> methods = {};
  late Subscription<dynamic> sub;
  late String nats_addr, server_name;

  QuasarServer(String nats_server_address, name) {
    super.identifier = name;

    server_name = name;
    nats_addr = nats_server_address;

    super.client.connect(Uri.parse(nats_server_address));
    sub = super.client.sub(name);

    unawaited(sub.stream.forEach(_gen_resp));
  }

  void registerMethod(String methodName, Function method) {
    methods[methodName] = method;
  }

  void _gen_resp(Message event) async {
    final JSON_RPC jsonRPC;

    try {
      jsonRPC = JSON_RPC.fromJson(jsonDecode(event.string));
    } on FormatException {
      // CAN NOT RETURN AN ERROR BECAUSE THE RETURN ADDRESS WAS IN THE JSON
      return null;
    } catch (e) {
      // JSON CAN BE DECODED BUT CANT FIT TO THE JSON_RPC CLASS
      try {
        var jsonRPC = jsonDecode(event.string);

        if (jsonRPC['params']['return_addr'] != null) {
          var jsonRPC_err = JSON_RPC_Err({
            'code': error_code.INVALID_REQUEST,
            'message': error_code.name(error_code.INVALID_REQUEST),
            'data': {'request': jsonRPC, 'full': e.toString()}
          }, jsonRPC['id'].asNum);

          unawaited(client.pubString(
              jsonRPC._params._return_addr!, jsonEncode(jsonRPC_err)));
        }
        // ignore: empty_catches
      } catch (e) {}

      return null;
    }

    if (!methods.containsKey(jsonRPC.method)) {
      var jsonRPC_err = JSON_RPC_Err({
        'code': error_code.METHOD_NOT_FOUND,
        'message': error_code.name(error_code.METHOD_NOT_FOUND)
      }, jsonRPC.id);

      unawaited(client.pubString(
          jsonRPC.params.return_addr!, jsonEncode(jsonRPC_err)));
      return null;
    }

    var result;
    try {
      if (jsonRPC.params.data == null || jsonRPC.params.data!.isEmpty) {
        result = methods[jsonRPC.method]!();
      } else {
        result = methods[jsonRPC.method]!(jsonRPC.params);
      }
    } on NoSuchMethodError {
      var jsonRPC_err = JSON_RPC_Err({
        'code': error_code.INVALID_PARAMS,
        'message': error_code.name(error_code.INVALID_PARAMS)
      }, jsonRPC.id);

      unawaited(client.pubString(
          jsonRPC.params.return_addr!, jsonEncode(jsonRPC_err)));
      return null;
    } catch (e) {
      var jsonRPC_err = JSON_RPC_Err({
        'code': error_code.SERVER_ERROR,
        'message': error_code.name(error_code.SERVER_ERROR) ?? e.toString(),
        'data': {'request': jsonRPC, 'full': e.toString()}
      }, jsonRPC.id);

      unawaited(client.pubString(
          jsonRPC.params.return_addr!, jsonEncode(jsonRPC_err)));
      return null;
    }

    // result = result.toString();

    var jsonRPC_ret = JSON_RPC_Ret(result, jsonRPC.id);

    if (jsonRPC.params.return_addr != null) {
      unawaited(client.pubString(
          jsonRPC.params.return_addr!, jsonEncode(jsonRPC_ret)));
    }
  }
}
