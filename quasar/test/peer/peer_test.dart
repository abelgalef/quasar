import 'dart:async';
import 'dart:convert';

import 'package:pedantic/pedantic.dart';
import 'package:quasar/src/models.dart';
import 'package:quasar/src/peer.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'utils.dart';
import '../../lib/error_code.dart' as error_code;

void main() {
  late QuasarPeer? peer1;
  late QuasarPeerController? server;

  final nats_server = 'nats://127.0.0.1:4222',
      peer1_name = 'my-peer-1',
      server_name = 'my-test-server-1';

  group('like a client', () {
    setUp(() async {
      peer1 = QuasarPeer(peer1_name, 'place', nats_server);
      server = QuasarPeerController(server_name, 'place', nats_server);

      unawaited(server!.listen());
      await peer1!.listen();
    });

    tearDown(() async {
      await peer1!.close();
      await server!.close();

      peer1 = null;
      server = null;
    });

    test('can send a message and receive a response', () async {
      var rawJson = server!.getReadyForIncomingData(
          jsonEncode({'jsonrpc': '2.0', 'result': 'bar', 'id': 1234}));

      expect(peer1!.sendRequest('foo', {'param': 'value'}),
          completion(equals('bar')));

      expect(
          jsonDecode(await rawJson),
          allOf([
            containsPair('jsonrpc', '2.0'),
            containsPair('method', 'foo'),
            containsPair(
                'params',
                allOf(containsPair('return_addr', isA<String>()),
                    containsPair('data', {'param': 'value'}))),
            containsPair(
                'id', allOf([isA<int>(), lessThan(100), greaterThan(0)]))
          ]));
    });

    test('sends a message and expects no response', () async {
      var rawJson = server!.getReadyForIncomingData('{}');
      peer1!.sendNotification('foo', {'param': 'param'});

      expect(
          jsonDecode(await rawJson),
          allOf([
            containsPair('jsonrpc', '2.0'),
            containsPair('method', 'foo'),
            containsPair(
                'params',
                allOf([
                  containsPair('return_addr', null),
                  containsPair('data', {'param': 'param'})
                ])),
            containsPair(
                'id', allOf([isA<int>(), lessThan(100), greaterThan(0)]))
          ]));
    });
    test('sends a notification with no parameters', () async {
      var rawJson = server!.getReadyForIncomingData('{}');
      peer1!.sendNotification('foo');

      expect(
          jsonDecode(await rawJson),
          allOf([
            containsPair('jsonrpc', '2.0'),
            containsPair('method', 'foo'),
            containsPair(
                'params',
                allOf([
                  containsPair('return_addr', null),
                  containsPair('data', {})
                ])),
            containsPair(
                'id', allOf([isA<int>(), lessThan(100), greaterThan(0)]))
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

      await expectLater(
          peer1!.sendRequest('foo', {'param': 'param'}),
          throwsA(isA<JSON_RPC_Err>()
              .having((e) => e.code, 'code', equals(error_code.SERVER_ERROR))
              .having((e) => e.message, 'message',
                  equals('you are bad at requests'))
              .having((e) => e.data, 'data', equals('some junk data'))));

      expect(
          jsonDecode(await rawJson),
          allOf([
            containsPair('jsonrpc', '2.0'),
            containsPair('method', 'foo'),
            containsPair(
                'params',
                allOf(containsPair('return_addr', isA<String>()),
                    containsPair('data', {'param': 'param'}))),
            containsPair(
                'id', allOf([isA<int>(), lessThan(101), greaterThan(-1)]))
          ]));
    });
  });

  group('like a server', () {
    setUp(() async {
      peer1 = QuasarPeer(peer1_name, 'place', nats_server);
      server = QuasarPeerController(server_name, 'place', nats_server);

      unawaited(server!.listen());
      await peer1!.listen();
    });

    tearDown(() async {
      await peer1!.close();
      await server!.close();

      peer1 = null;
      server = null;
    });

    test('calls a registered method with the given name', () {
      peer1!.registerMethod('foo', (params) {
        return params.data;
      });

      expect(
          server!.sendReq(jsonEncode({
            'jsonrpc': '2.0',
            'method': 'foo',
            'params': {
              'return_addr': server!.ret_addr,
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
      peer1!.registerMethod('foo', () => 'foo');

      expect(
          server!.sendReq(jsonEncode({
            'jsonrpc': '2.0',
            'method': 'foo',
            'params': {'return_addr': server!.ret_addr, 'data': {}},
            'id': 1234
          })),
          completion(equals(
              jsonEncode({'jsonrpc': '2.0', 'result': 'foo', 'id': 1234}))));
    });

    test('Allows a `null` result', () {
      peer1!.registerMethod('foo', () => null);

      expect(
          server!.sendReq(jsonEncode({
            'jsonrpc': '2.0',
            'method': 'foo',
            'params': {'return_addr': server!.ret_addr, 'data': null},
            'id': 1234
          })),
          completion(equals(
              jsonEncode({'jsonrpc': '2.0', 'result': null, 'id': 1234}))));
    });

    test('a method that takes no parameters rejects parameteres', () {
      peer1!.registerMethod('foo', () => 'foo');

      expect(
          server!.sendReq(jsonEncode({
            'jsonrpc': '2.0',
            'method': 'foo',
            'params': {
              'return_addr': server!.ret_addr,
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
      peer1!.registerMethod('foo', () => throw FormatException('bad format'));

      expect(
          server!.sendReq(jsonEncode({
            'jsonrpc': '2.0',
            'method': 'foo',
            'params': {'return_addr': server!.ret_addr, 'data': null},
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
                  'params': {'return_addr': server!.ret_addr, 'data': null},
                  'id': 1234
                },
                'full': 'FormatException: bad format'
              },
            },
            'id': 1234
          }))));
    });
  });
}
