import 'dart:convert';
import 'dart:math';

import 'package:dart_nats/dart_nats.dart';
import 'package:quasar/quasar.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../lib/error_code.dart' as error_code;
import 'utils.dart';

void main() {
  final uuid = Uuid();
  final nats_server = 'nats://127.0.0.1:4222', server_name = 'my-test-server-1';

  late ServerController? client;
  late QuasarServer? server;

  setUp(() async {
    server = QuasarServer(nats_server, server_name);
    await server!.client.waitUntilConnected();
    client = ServerController(nats_server, server_name, uuid.v4());
  });

  tearDown(() async {
    await client!.close();
    await server!.close();
    server = null;
    client = null;
  });

  test('calls a registered method with the given name', () {
    server!.registerMethod('foo', (params) {
      return params.data;
    });

    expect(
        client!.sendReq(jsonEncode({
          'jsonrpc': '2.0',
          'method': 'foo',
          'params': {
            'return_addr': client!.client_addr,
            'data': {'some': 'value'}
          },
          'id': 1234
        })),
        completion(equals(jsonEncode({
          'jsonrpc': '2.0',
          'result': {'some': 'value'},
          'id': 1234
        }))));
  });

  test('calls a method that takes no parameteres', () {
    server!.registerMethod('foo', () => 'foo');

    expect(
        client!.sendReq(jsonEncode({
          'jsonrpc': '2.0',
          'method': 'foo',
          'params': {'return_addr': client!.client_addr, 'data': {}},
          'id': 1234
        })),
        completion(equals(
            jsonEncode({'jsonrpc': '2.0', 'result': 'foo', 'id': 1234}))));
  });

  test('Allows a `null` result', () {
    server!.registerMethod('foo', () => null);

    expect(
        client!.sendReq(jsonEncode({
          'jsonrpc': '2.0',
          'method': 'foo',
          'params': {'return_addr': client!.client_addr, 'data': null},
          'id': 1234
        })),
        completion(equals(
            jsonEncode({'jsonrpc': '2.0', 'result': null, 'id': 1234}))));
  });

  test('a method that takes no parameters rejects parameteres', () {
    server!.registerMethod('foo', () => 'foo');

    expect(
        client!.sendReq(jsonEncode({
          'jsonrpc': '2.0',
          'method': 'foo',
          'params': {
            'return_addr': client!.client_addr,
            'data': {'some': 1}
          },
          'id': 1234
        })),
        completion(equals(jsonEncode({
          'jsonrpc': '2.0',
          'error': {
            'code': error_code.INVALID_PARAMS,
            'message': error_code.name(error_code.INVALID_PARAMS)
          },
          'id': 1234
        }))));
  });

  test('an unexpected error in a method is captured', () {
    server!.registerMethod('foo', () => throw FormatException('bad format'));

    expect(
        client!.sendReq(jsonEncode({
          'jsonrpc': '2.0',
          'method': 'foo',
          'params': {'return_addr': client!.client_addr, 'data': null},
          'id': 1234
        })),
        completion(equals(jsonEncode({
          'jsonrpc': '2.0',
          'error': {
            'code': error_code.SERVER_ERROR,
            'message': 'FormatException: bad format',
            'data': {
              'request': {
                'jsonrpc': '2.0',
                'method': 'foo',
                'params': {'return_addr': client!.client_addr, 'data': null},
                'id': 1234
              },
              'full': 'FormatException: bad format'
            },
          },
          'id': 1234
        }))));
  });

  test('doesn\'t return a result for a notification', () {
    server!.registerMethod('foo', (params) => 'result');

    expect(
        client!.sendReq(jsonEncode({
          'jsonrpc': '2.0',
          'method': 'foo',
          'params': {'return_addr': client!.client_addr, 'data': null},
          'id': 1234
        })),
        doesNotComplete);
  });

  test('a JSON parse error is rejected', () {
    expect(client!.sendReq('{hi'), doesNotComplete);
  });
}
