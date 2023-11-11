import 'package:dart_nats/dart_nats.dart';

class ServerController {
  late String nats_addr, server_addr, client_addr;
  final client = Client();
  late Subscription sub;

  ServerController(nats_addr, server_addr, client_addr) {
    this.nats_addr = nats_addr;
    this.server_addr = server_addr;
    this.client_addr = client_addr;

    client.connect(Uri.parse(nats_addr));
    sub = client.sub(client_addr);
  }

  Future<String> sendReq(String msg) async {
    await client.waitUntilConnected();

    var recv = await client.requestString(server_addr, msg);

    return recv.string;
  }

  Future sendNotification(String msg) async {
    await client.waitUntilConnected();

    return client.pubString(server_addr, msg);
  }

  Future<dynamic> close() {
    return client.close();
  }
}
