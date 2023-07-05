import 'package:pedantic/pedantic.dart';
import 'package:quasar/quasar.dart';

void main(List<String> arguments) async {
  var server = QuasarServer('nats://127.0.0.1:4222', 'my-test-server-1');

  var i = 5;
  // ADD A METHOD TO SERVER
  server.registerMethod('count', () {
    return i++;
  });

  server.registerMethod('echo', (Parameters params) {
    return params.data!['message'];
  });

  var client = QuasarClient('nats://127.0.0.1:4222', 'my-test-server-1');
  await client.listen();

  // SEND A NOTIFICATION TO THE SERVER
  client.sendNotification('count');
  client.sendNotification('count');
  client.sendNotification('count');
  client.sendNotification('count');

  var count = await client.sendRequest('count');
  print('Count is $count');

  var echo = await client.sendRequest('echo', {'message': 'hello'});
  print('Echo says $echo');

  // CLOSE THE SERVER AND CLIENT
  await server.close();
  await client.close();

  // CREATE PEERS WITH A UNIQUE NAME AND A RENDEVUZ POINT
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
}
