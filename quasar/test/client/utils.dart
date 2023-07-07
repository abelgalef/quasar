import 'dart:async';
import 'dart:convert';

import 'package:dart_nats/dart_nats.dart';
import 'package:pedantic/pedantic.dart';
import 'package:quasar/src/models.dart';

class ClientController {
  final nats_server = 'nats://127.0.0.1:4222', server_name = 'my-test-server-1';
  late String answer;
  late String ret_addr;

  final client = Client();
  late Subscription sub;
  late Completer completer;

  ClientController() {
    client.connect(Uri.parse(nats_server));
    sub = client.sub(server_name);

    unawaited(sub.stream.forEach(gen_resp));
  }

  Future getReadyForIncomingData(String answer) {
    completer = Completer();
    this.answer = answer;

    return completer.future;
  }

  void gen_resp(Message msg) async {
    completer.complete(msg.string);

    msg.respondString(answer);
  }
}
