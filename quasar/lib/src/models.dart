import 'dart:convert';

import 'package:dart_nats/dart_nats.dart';
import '../error_code.dart' as error_code;

class Quasar {
  Client client = Client();
  late String identifier;

  Future close() async {
    return client.close();
  }
}

class Parameters {
  final String? _return_addr;
  final Map<String, dynamic>? _data;

  Parameters(this._return_addr, this._data);

  Map<String, dynamic>? get data => _data;
  String? get return_addr => _return_addr;

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

  String get method => _method;

  int get id => _id;

  Parameters get params => _params;

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
  final Map<String, dynamic>? _data;

  dynamic get result => _result;

  int get id => _id;

  JSON_RPC_Ret(this._result, this._id, [this._data]);

  Map<String, dynamic> toJson() {
    if (_data != null) {
      return {'jsonrpc': _jsonrpc, 'result': _result, 'id': _id, 'data': _data};
    }

    return {'jsonrpc': _jsonrpc, 'result': _result, 'id': _id};
  }

  JSON_RPC_Ret.fromJson(Map<String, dynamic> json)
      : _id = json['id'],
        _result = json['result'],
        _data = json['data'];
}

class JSON_RPC_Err implements Exception {
  final String _jsonrpc = '2.0';
  final dynamic _error;
  final int? _id;

  dynamic get error => _error;

  int get code => _error['code'];
  String get message => _error['message'];
  String get data => _error['data'];

  int? get id => _id;

  JSON_RPC_Err(this._error, this._id);

  @override
  String toString() {
    return 'JSON RPC Error: ' + _error.toString();
  }

  Map<String, dynamic> toJson() =>
      {'jsonrpc': _jsonrpc, 'error': _error, 'id': _id};

  JSON_RPC_Err.fromJson(Map<String, dynamic> json)
      : _id = json['id'],
        _error = json['error'];
}
