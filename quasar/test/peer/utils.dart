import 'dart:async';
import 'dart:convert';

import 'package:dart_nats/dart_nats.dart';
import 'package:pedantic/pedantic.dart';
import 'package:quasar/src/models.dart';
import 'package:uuid/uuid.dart';

class PeerController {
  final nats_server = 'nats://127.0.0.1:4222';

  late String server_name;
  late String answer;

  final client = Client();
  late Subscription sub;
  late Completer completer;

  final ret_addr = Uuid().v4();
  final peerID = Uuid().v4();

  PeerController(String server_name, String type) {
    this.server_name = server_name;

    client.connect(Uri.parse(nats_server));

    if (type == 'server') {
      sub = client.sub(server_name);
      unawaited(sub.stream.forEach(gen_resp));
    } else {
      sub = client.sub(ret_addr);
    }
  }

  Future close() {
    return client.close();
  }

  Future listen() async {
    await client.waitUntilConnected();

    return client.pubString(
        server_name,
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'ackConn',
          'params': {
            'return_addr': null,
            'data': {'remoteAddr': server_name}
          },
          'id': 1234
        }));
  }

  Future getReadyForIncomingData(String answer) {
    completer = Completer();
    this.answer = answer;

    return completer.future;
  }

  void gen_resp(Message msg) async {
    // print(msg.string);
    completer.complete(msg.string);

    var jsonRPC = JSON_RPC.fromJson(jsonDecode(msg.string));
    if (jsonRPC.params.return_addr != null) {
      unawaited(client.pubString(jsonRPC.params.return_addr!, answer));
    }
  }

  Future<String> sendReq(String msg) async {
    await client.waitUntilConnected();
    await client.pubString(server_name, msg);

    var recv = await sub.stream.first;

    return recv.string;
  }
}
