# Quasar

## JSON RPC 2 over NATS.

[![Version](https://img.shields.io/badge/version-0.1.1-blue)](https://github.com/abelgalef/quasar/commit/63e8c37113eb9a7a393f4be266e2104b79fae6e1) [![Version](https://img.shields.io/badge/build-passed-green)](https://github.com/abelgalef/quasar/commit/63e8c37113eb9a7a393f4be266e2104b79fae6e1)

Quasar is a lightweight and performant Dart package that implements the JSON RPC 2 Spec over the NATS Pub/Sub architecture.

**Supported Platforms:**
- Android
- iOS
- Linux
- MacOS
- Web
- Windows

## Features

- Implements the entire JSON RPC 2 Spec.
- Uses NATS to communicate.
- Can be used as a server, client, or peer.
- Peer auto-discovery.
- Uses subjects to pass parameters.

## Installation

Quasar requires [Dart](https://dart.dev/) v2.0+ to run.

Install the package and start the NATS server.

```sh
pub add quasar
```

## Usage

```dart
import 'package:pedantic/pedantic.dart';
import 'package:quasar/quasar.dart';

void main(List<String> arguments) async {
  // We start a server and pass our NATS server address and a unique name or subject (prefix) to subscribe to.
  var server = QuasarServer('nats://127.0.0.1:4222', 'my-unique-server-name-1');

  var i = 5;
  // Any string may be used as a method name. Methods are case-sensitive.
  server.registerMethod('count', () {
    // Just return the value to be sent as a response to the client. This can
    // be anything JSON-serializable.
    return i++;
  });

  // Methods can take parameters. They are presented as a Map<String, dynamic> object
  // which makes it easy to validate that the expected parameters exist.
  server.registerMethod('echo', (Parameters params) {
    // If the request doesn't have a "message" parameter, this will
    // automatically send a response notifying the client that the request
    // was invalid.
    return params.data!['message'];
  });

  // A method can send an error response by throwing any `Exception`.
  // Any positive number may be used as an application-defined error code.
  const divideByZero = 1;
  server.registerMethod('divide', (Parameters params) {
    var divisor = params.data!['divisor'];
    if (divisor == 0) {
      throw JSON_RPC_Err('Cannot divide by zero.', divideByZero);
    }

    return int.parse(params.data!['dividend']) / divisor;
  });

  // We start a client and pass our NATS server address and the name of the server or subject (server prefix) to publish to.
  var client = QuasarClient('nats://127.0.0.1:4222', 'my-test-server-1');

  // The client won't subscribe to the input stream until you call `listen`.
  // The returned Future won't complete until the connection is closed.
  await client.listen();

  // A notification is a way to call a method that tells the server that no
  // result is expected. Its return type is `void`; even if it causes an
  // error, you won't hear back.
  client.sendNotification('count');

  // This calls the "count" method on the server. A Future is returned that
  // will complete to the value contained in the server's response.
  var count = await client.sendRequest('count');
  print('Count is $count');

  // Parameters are passed as a simple Map. Make sure they're JSON-serializable!
  var echo = await client.sendRequest('echo', {'message': 'hello'});
  print('Echo says $echo');

  // If the server sends an error response, the returned Future will complete
  // with an RpcException. You can catch this error and inspect its error
  // code, message, and any data that the server sent along with it.
  try {
    await client.sendRequest('divide', {'dividend': 2, 'divisor': 0});
  } on JSON_RPC_Err catch (error) {
    print('JSON RPC error ${error.code}: ${error.message}');
  }

  // CLOSE THE SERVER AND CLIENT
  await server.close();
  await client.close();
}
```

## Usage as a Peer

Although JSON-RPC 2.0 only explicitly describes clients and servers, it also mentions that two-way communication can be supported by making each endpoint both a client and a server. This package supports this directly using the `Peer` class, which implements both `Client` and `Server`. It supports the same methods as those classes and automatically makes sure that every message from the other endpoint is routed and handled correctly.

```dart
// CREATE PEERS WITH A UNIQUE NAME AND A RENDEZVOUS POINT
var peer1 = QuasarPeer('i-am-peer-1', 'place', 'nats://127.0.0.1:4222');
var peer2 = QuasarPeer('i-am-peer-2', 'place', 'nats://127.0.0.1:4222');

// WAIT FOR PEERS TO DISCOVER EACH OTHER
unawaited(peer1.listen());
await peer2.listen();

peer1.registerMethod('name', () => 'peer 1');

peer2.registerMethod('time', () => DateTime.now().toString());

var time = await peer1.sendRequest('time');
print('Peer 2 - time $time');

var name = await peer2.sendRequest('name');
print('Peer 1 - name $name');

// CLOSE PEERS
await peer1.close();
await peer2.close();
```

## License

MIT

**Free Software, Hell Yeah!**