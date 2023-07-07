import 'dart:convert';

import 'package:dart_nats/dart_nats.dart';
import '../error_code.dart' as error_code;

/// Quasar Class that contains the underlying dart_nats client.
class Quasar {
  /// The actual dart_nats client that is used to communicate with the NATS server.
  Client client = Client();

  /// An unique identifier used for identifying this client instance in the pool of the NATS clients.
  late String identifier;

  /// A function used to close the connection to the NATS server
  Future close() async {
    return client.close();
  }
}

/// Parametes Class used to represent the data that is sent to the server.
class Parameters {
  /// This String is used to identify this specific request.
  // final String? _return_addr;

  /// This Map contains all the data that is going to be sent to the function invoked.
  final Map<String, dynamic>? _data;

  /// Constructor for the [Parameters] class which creates a [Parameters] object with a return address [_return_addr] and data [_data].
  ///
  /// @param String `return_addr` The return address of the request (Usually a UUID).
  ///
  /// @param Map<String, dynamic> `data` The supplied data for the request method.
  Parameters(this._data);

  /// The data [_data] and return address [_return_addr] used by the [Parameters] Class.
  Map<String, dynamic>? get data => _data;
  // String? get return_addr => _return_addr;

  /// Transforms a [Parameters] object and returns to a JSON Object.
  ///
  /// @param `return_addr` The return address of the request (Usually a UUID).
  ///
  /// @param `data` The supplied data for the request method.
  ///
  /// Example Object:
  /// {'return_addr': 'my-very-unique-address', 'data': {'foo': 'bar'}}
  Map<String, dynamic> toJson() => {'data': _data};

  /// Transforms a Map or a JSON object with keys `return_addr` and `data` to a [Parameters] object.
  Parameters.fromJson(Map<String, dynamic> json)
      // : _return_addr = json['return_addr'],
      : _data = json['data'];
}

/// A JSON RPC Request class.
class JSON_RPC {
  /// The JSON RPC version.
  final String _jsonrpc = '2.0';

  /// The name of the method being invoked.
  final String _method;

  /// A randomly generated id number.
  final int _id;

  /// A [Parameters] object used to store the unique request ID and the parameters to pass to the invoked method.
  final Parameters _params;

  String get method => _method;

  int get id => _id;

  Parameters get params => _params;

  /// Constructor for the [JSON_RPC] class to create a [JSON_RPC] object with a String method [_method], String id [id] and [Parameters] object [_params].
  ///
  /// @param String `method` The method to be invoked.
  ///
  /// @param int `id`  the id of the JSON RPC object
  JSON_RPC(this._method, this._id, this._params);

  /// Transforms a [JSON_RPC] object and returns to a JSON Object.
  ///
  /// @param String `jsonrpc` The version of the spec we are using (Usually "2.0").
  ///
  /// @param String `method` The method to be invoked.
  ///
  /// @param [Parameters] `params` The data to be passed to the invoked method.
  ///
  /// Example Object:
  /// {'jsonrpc': '2.0', 'method':'foo', 'params':{'return_addr':'my-addy', 'data':{'bar':'baz'}}, 'id':1234}
  Map<String, dynamic> toJson() => {
        'jsonrpc': _jsonrpc,
        'method': _method,
        'params': _params.toJson(),
        'id': _id
      };

  String toString() => {
        'jsonrpc': _jsonrpc,
        'method': _method,
        'params': _params.toJson(),
        'id': _id
      }.toString();

  /// Transforms a Map or a JSON object with keys `id`, `method` and `params` to a [JSON_RPC] object.
  JSON_RPC.fromJson(Map<String, dynamic> json)
      : _id = json['id'],
        _method = json['method'],
        _params = Parameters.fromJson(json['params']);
}

/// A JSON RPC response class.
class JSON_RPC_Ret {
  /// The JSON RPC version.
  final String _jsonrpc = '2.0';

  /// The returned result from the invoked method.
  final dynamic _result;

  /// The id of the [JSON_RPC] request.
  final int _id;

  final Map<String, dynamic>? _data;

  dynamic get result => _result;

  int get id => _id;

  /// Constructor for the [JSON_RPC_Ret] class.
  ///
  /// @param `_result` dynamic The result to be invoked.
  ///
  /// @param `_id` int The id of the JSON_RPC request.
  ///
  /// @param `_data` Map<String, dynamic> Additional data to be sent.
  JSON_RPC_Ret(this._result, this._id, [this._data]);

  /// Transforms a [JSON_RPC_Ret] object and returns to a JSON Object.
  ///
  /// @param `jsonrpc` String The version of the spec we are using (Usually "2.0").
  ///
  /// @param `result` String The method to be invoked.
  ///
  /// @param `data` Map<String, dynamic> Additional data to be sent.
  ///
  /// Example Object:
  /// {'jsonrpc': '2.0', 'result': 43, 'id':1234, 'data':{'data-1':'my-data-1', 'data-2':'my-data-2}}
  Map<String, dynamic> toJson() {
    if (_data != null) {
      return {'jsonrpc': _jsonrpc, 'result': _result, 'id': _id, 'data': _data};
    }

    return {'jsonrpc': _jsonrpc, 'result': _result, 'id': _id};
  }

  /// Transform a Map or JSON object to a [JSON_RPC_Ret] object.
  JSON_RPC_Ret.fromJson(Map<String, dynamic> json)
      : _id = json['id'],
        _result = json['result'],
        _data = json['data'];
}

/// A JSON RPC error class
class JSON_RPC_Err implements Exception {
  /// The JSON RPC version.
  final String _jsonrpc = '2.0';

  /// The returned error map to with data, code and message.
  final dynamic _error;

  /// The id of the [JSON_RPC] object.
  final int? _id;

  dynamic get error => _error;

  /// Get the error code, error message and error data from the object.
  int get code => _error['code'];
  String get message => _error['message'];
  String get data => _error['data'];

  int? get id => _id;

  /// Constructor for the [JSON_RPC_Err] class.
  ///
  /// @param dynamic `_error` The error to be returned.
  ///
  /// @param int `_id` The id of the JSON_RPC request.
  JSON_RPC_Err(this._error, this._id);

  @override
  String toString() {
    return 'JSON RPC Error: ' + _error.toString();
  }

  /// Transforms a [JSON_RPC_Err] object and returns to a JSON Object.
  ///
  /// @param `jsonrpc` String The version of the spec we are using (Usually "2.0").
  ///
  /// @param `error` Map<String, dynamic> A Map object which contains the error code, the error message and the additional data for the error.
  ///
  /// @param `id` int ID for the [JSON_RPC] request.
  ///
  /// Example Object:
  /// {'jsonrpc': '2.0', 'error': {'code': -32000, 'message': 'you are bad at requests', 'data': 'some junk data'}, 'id': 1234}
  Map<String, dynamic> toJson() =>
      {'jsonrpc': _jsonrpc, 'error': _error, 'id': _id};

  /// Transforms a Map or JSON object to a [JSON_RPC_Ret] object.
  JSON_RPC_Err.fromJson(Map<String, dynamic> json)
      : _id = json['id'],
        _error = json['error'];
}
