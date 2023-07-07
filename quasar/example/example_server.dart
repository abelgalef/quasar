import 'package:quasar/quasar.dart';

void main() {
  var server =
      QuasarServer('nats://127.0.0.1:4222', 'my-example-server-name-1');

  server.registerMethod('echo', (Parameters params) {
    var msg = params.data!['message'];

    print('Client said: $msg at ' + DateTime.now().toString());

    return 'This is a messege from the server ' + msg;
  });

  print('Server created and methods registered. Waiting for requests.');
}
