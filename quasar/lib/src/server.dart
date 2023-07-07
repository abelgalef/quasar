import 'dart:convert';

import 'package:dart_nats/dart_nats.dart';
import 'package:pedantic/pedantic.dart';

import '../error_code.dart' as error_code;
import 'models.dart';

/// A Quasar Server class that extends the [Quasar] class.
class QuasarServer extends Quasar {
  /// Collection of methods the server can invoke.
  Map<String, Function> methods = {};

  /// The NATS subject (prefix) subscription.
  late Subscription<dynamic> sub;

  /// The NATS server address and the unique name of this server.
  late String nats_addr, server_name;

  /// The Server prefix.
  late String prefix;

  /// If true invokes the method from the subject.
  bool _methodFromSubject = false;

  /// If true adds a segments key and a value List<String> to the [Parameters] passed to the function.
  bool _useSegments = false;

  bool get getMethodFromSubject => _methodFromSubject;

  /// Setter for the [_methodFromSubject] boolean.
  set setMethodFromSubject(bool methodFromSubject) {
    _methodFromSubject = methodFromSubject;
    var _prefixes =
        prefix.split('.'); // Turn the subject into a list of strings.

    if (methodFromSubject) {
      // If true add the `>` keyword to the subject we are subscribed to.
      if (_prefixes[_prefixes.length - 1] != '>') {
        _prefixes.add('>');
      }
    } else {
      if (_prefixes[_prefixes.length - 1] == '>') {
        _prefixes[_prefixes.length - 1] = '';
      }
    }

    prefix = _prefixes.join(
        '.'); // Turns the List of strings to a usable string concatenated by `.`.

    // Unsubscribe from the previous subject and subscribe to the new and improved subject.
    super.client.unSub(sub);
    sub = super.client.sub(prefix);

    // Handel the messages gotten from the new subscription.
    unawaited(sub.stream.forEach(_gen_resp));
  }

  bool get getUseSegments => _useSegments;

  /// Setter for the [_useSegments] boolean.
  set setUseSegments(useSegments) {
    _useSegments = useSegments;
    var _prefixes =
        prefix.split('.'); // Turn the subject into a list of strings.

    if (useSegments) {
      // If true add the `>` keyword to the subject we are subscribed to.
      if (_prefixes[_prefixes.length - 1] != '>') {
        _prefixes.add('>');
      }
    } else {
      if (_prefixes[_prefixes.length - 1] == '>') {
        _prefixes[_prefixes.length - 1] = '';
      }
    }

    prefix = _prefixes.join(
        '.'); // Turns the List of strings to a usable string concatenated by `.`.

    // Unsubscribe from the previous subject and subscribe to the new and improved subject.
    super.client.unSub(sub);
    sub = super.client.sub(prefix);

    // Handel the messages gotten from the new subscription.
    unawaited(sub.stream.forEach(_gen_resp));
  }

  /// Constructor for the [QuasarServer] class.
  ///
  /// @param String `nats_server_address` The NATS server address to connect to.
  ///
  /// @param String `name` The unique name of the server or the subject (prefix) to subscribe to.
  QuasarServer(String nats_server_address, name) {
    prefix = name;
    super.identifier = name;

    server_name = name;
    nats_addr = nats_server_address;

    // Connect to the NATS server.
    super.client.connect(Uri.parse(nats_server_address));
    sub = super
        .client
        .sub(prefix); // Subscribe to the server prefix or our unique name.

    // Handel the requsts with the _gen_resp function.
    unawaited(sub.stream.forEach(_gen_resp));
  }

  /// Add a function this server can invoke.
  ///
  /// @param String `methodName` The name of the method.
  ///
  /// @param Function `method` The function to add.
  void registerMethod(String methodName, Function method) {
    methods[methodName] = method;
  }

  /// Takes in a raw Message object and transfroms it to a String.
  ///
  /// The transformation only takes place if either of the [_methodFromSubject] and/or [_useSegments] is true.
  String transformMessage(Message rawMsg) {
    var subject = rawMsg.subject;

    var transformedMsg = jsonDecode(rawMsg.string);

    // Remove the server prefix from the subject.
    var _prefixes = subject!.replaceFirst(super.identifier + '.', '');
    if (_methodFromSubject) {
      transformedMsg['method'] = _prefixes.split('.')[0];
    }

    if (_useSegments) {
      var idx = 0;
      // If [_methodFromSubject] is true then skip the first segment as it is a comand.
      if (_methodFromSubject) {
        idx++;
      }

      transformedMsg['params']['data']['segments'] = _prefixes
          .split('.')
          .getRange(idx, _prefixes.split('.').length)
          .toList();
    }

    // Return a String
    return jsonEncode(transformedMsg);
  }

  /// Takes in a raw message (request) from the NATS server and sends a response.
  void _gen_resp(Message event) async {
    final JSON_RPC jsonRPC;

    try {
      var msg = transformMessage(event);

      jsonRPC = JSON_RPC.fromJson(jsonDecode(msg));
    } catch (e) {
      // JSON CAN NOT BE DECODED.
      try {
        var jsonRPC = jsonDecode(event.string);

        var jsonRPC_err = JSON_RPC_Err({
          'code': error_code.INVALID_REQUEST,
          'message': error_code.name(error_code.INVALID_REQUEST),
          'data': {'request': jsonRPC, 'full': e.toString()}
        }, int.parse(jsonRPC['id']));

        event.respondString(jsonEncode(jsonRPC_err.toJson()));

        // ignore: empty_catches
      } catch (e) {
        event.respondString(jsonEncode(JSON_RPC_Err({
          'code': error_code.INVALID_REQUEST,
          'message': error_code.name(error_code.INVALID_REQUEST),
          'data': {'request': event.string, 'full': e.toString()}
        }, -1)
            .toString()));
      }
      return null;
    }

    // Check if the invoked method exists.
    if (!methods.containsKey(jsonRPC.method)) {
      var jsonRPC_err = JSON_RPC_Err({
        'code': error_code.METHOD_NOT_FOUND,
        'message': error_code.name(error_code.METHOD_NOT_FOUND)
      }, jsonRPC.id);

      event.respondString(jsonEncode(jsonRPC_err.toJson()));
      return null;
    }

    // Generate a result for the response.
    var result;
    try {
      if (jsonRPC.params.data == null || jsonRPC.params.data!.isEmpty) {
        result = methods[jsonRPC.method]!();
      } else {
        result = methods[jsonRPC.method]!(jsonRPC.params);
      }
    } on NoSuchMethodError {
      // Invalid Params because methods exists but the params are not right.
      var jsonRPC_err = JSON_RPC_Err({
        'code': error_code.INVALID_PARAMS,
        'message': error_code.name(error_code.INVALID_PARAMS)
      }, jsonRPC.id);

      event.respondString(jsonEncode(jsonRPC_err.toJson()));
      return;
    } catch (e) {
      // print('fadfa');
      // Get the error thrown by the method.
      var jsonRPC_err = JSON_RPC_Err({
        'code': error_code.SERVER_ERROR,
        'message': error_code.name(error_code.SERVER_ERROR) ?? e.toString(),
        'data': {'request': jsonRPC, 'full': e.toString()}
      }, jsonRPC.id);

      event.respondString(jsonEncode(jsonRPC_err.toJson()));
      return null;
    }

    var jsonRPC_ret = JSON_RPC_Ret(result, jsonRPC.id);

    event.respondString(jsonEncode(jsonRPC_ret.toJson()));
  }
}
