import 'dart:io';

import 'package:quasar/quasar.dart';

void main() async {
  var client =
      QuasarClient('nats://127.0.0.1:4222', 'my-example-server-name-1');

  await client.listen();

  var exit = false;

  print(
      'Type a message to send to the server. Enter `quit` to exit the program.');
  while (!exit) {
    var msg = stdin.readLineSync();

    if (msg == 'quit') break;

    var reply = await client.sendRequest('echo', {'message': msg});
    print(reply);
  }

  await client.close();
}
