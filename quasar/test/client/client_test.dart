import 'dart:async';
import 'dart:convert';

import 'package:pedantic/pedantic.dart';
import 'package:quasar/quasar.dart';
import 'package:quasar/src/models.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'utils.dart';
import '../../lib/error_code.dart' as error_code;

void main() {
  final nats_server = 'nats://127.0.0.1:4222', server_name = 'my-test-server-1';
  late ClientController? server;
  late QuasarClient? client;

  setUp(() async {
    server = ClientController();
    await server!.client.waitUntilConnected();
    client = QuasarClient(nats_server, server_name);
    await client!.listen();
  });

  tearDown(() async {
    await server!.client.close();
    await client!.close();
    client = null;
    server = null;
  });

  test('sends a message and returns a response', () async {
    var rawJson = server!.getReadyForIncomingData(
        jsonEncode({'jsonrpc': '2.0', 'result': 'bar', 'id': 1234}));

    expect(client!.sendRequest('foo', {'param': 'param'}),
        completion(equals('bar')));

    expect(
        jsonDecode(await rawJson),
        allOf([
          containsPair('jsonrpc', '2.0'),
          containsPair('method', 'foo'),
          containsPair('params', containsPair('data', {'param': 'param'})),
          containsPair('id', allOf([isA<int>(), lessThan(100), greaterThan(0)]))
        ]));
  });

  test('sends a message and expects no response', () async {
    var rawJson = server!.getReadyForIncomingData('{}');
    client!.sendNotification('foo', {'param': 'param'});

    expect(
        jsonDecode(await rawJson),
        allOf([
          containsPair('jsonrpc', '2.0'),
          containsPair('method', 'foo'),
          containsPair(
              'params',
              allOf([
                containsPair('data', {'param': 'param'})
              ])),
          containsPair('id', allOf([isA<int>(), lessThan(100), greaterThan(0)]))
        ]));
  });

  test('sends a notification with no parameters', () async {
    var rawJson = server!.getReadyForIncomingData('{}');
    client!.sendNotification('foo');

    expect(
        jsonDecode(await rawJson),
        allOf([
          containsPair('jsonrpc', '2.0'),
          containsPair('method', 'foo'),
          containsPair('params', allOf([containsPair('data', {})])),
          containsPair('id', allOf([isA<int>(), lessThan(100), greaterThan(0)]))
        ]));
  });

  test('reports an error from the server', () async {
    var rawJson = server!.getReadyForIncomingData(jsonEncode({
      'jsonrpc': '2.0',
      'error': {
        'code': error_code.SERVER_ERROR,
        'message': 'you are bad at requests',
        'data': 'some junk data'
      },
      'id': 1234
    }));

    // var resp = client!.sendRequest('foo', {'param': 'param'});

    expect(
        client!.sendRequest('foo', {'param': 'param'}),
        (throwsA(isA<JSON_RPC_Err>()
            .having((e) => e.code, 'code', equals(error_code.SERVER_ERROR))
            .having(
                (e) => e.message, 'message', equals('you are bad at requests'))
            .having((e) => e.data, 'data', equals('some junk data')))));

    expect(
        jsonDecode(await rawJson),
        allOf([
          containsPair('jsonrpc', '2.0'),
          containsPair('method', 'foo'),
          containsPair('params', containsPair('data', {'param': 'param'})),
          containsPair(
              'id', allOf([isA<int>(), lessThan(101), greaterThan(-1)]))
        ]));
  });
}
