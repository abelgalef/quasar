import 'dart:async';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'package:quasar_test/quasar.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(new MaterialApp(
    home: new MyApp(),
  ));
}

class ChatMessage {
  String date, content, type, sender;
  ChatMessage(this.date, this.type, this.content, this.sender);
}

class MyApp extends StatefulWidget {
  @override
  _State createState() => new _State();
}

class _State extends State<MyApp> {
  final uuid = Uuid();
  late TextEditingController inputMsg, natServer;
  List<ChatMessage> listChat = [];

  String natsAddr = 'nats://demo.nats.io:4222';
  late String myUniqueName;
  late QuasarPeer me;
  late QuasarServer server; // FOR DISCOVERING PEERS ONLY!
  Timer? timer;

  String status = 'Enter your NATS Address and Click Save';

  @override
  void initState() {
    var rng = new Random();
    // randomID = 'USER' + rng.nextInt(10000).toString();
    inputMsg = new TextEditingController();
    natServer = new TextEditingController();
    natServer.text = natsAddr;
    myUniqueName = uuid.v4();

    initPeers();
  }

  @override
  dispose() {
    me.close();
  }

  initPeers() async {
    if (status == 'connected' || status == 'connecting') {
      status = 'not connected';
      await me.close();
    }
    me = QuasarPeer(myUniqueName, 'rendezvous', natsAddr);

    status = 'connecting';

    me.registerMethod('message', _getMessage);
    // me.sendNotification('message', {'type': 'text', 'content': 'test123'});

    me.listen().then((value) {
      setState(() {
        status = 'connected';
      });
    }).catchError((e) {
      setState(() {
        status = 'Error from peer';
      });
      print("+++++ " + e.toString());
    });
  }

  void _sendMessage() async {
    if (status == 'connected') {
      me.sendNotification(
          'message', {'type': 'text', 'content': inputMsg.text});
      setState(() {
        listChat.add(new ChatMessage(
            DateTime.now().toString(), 'text', inputMsg.text, myUniqueName));
      });
      inputMsg.clear();
    }
  }

  void _getMessage(dynamic params) {
    print(params);

    // print(data.data);

    setState(() {
      // status = data.data;
      listChat.add(new ChatMessage(DateTime.now().toString(),
          params.data['type'], params.data['content'], 'someone-else'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: new AppBar(
        title: new Text('Quasar Peer Chat app'),
        actions: [
          Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (BuildContext context) {
                      return SizedBox(
                        height: 200,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.only(right: 20.0, left: 20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Padding(
                                  padding: EdgeInsets.all(15),
                                  child: TextField(
                                    controller: natServer,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'NATS Server Address',
                                      hintText: 'Enter NATS Server Address',
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  child: const Text('Save'),
                                  onPressed: () {
                                    setState(() {
                                      natsAddr = natServer.text;
                                    });
                                    initPeers();
                                  },
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                child: Icon(
                  Icons.settings,
                  size: 26.0,
                ),
              ))
        ],
      ),
      body: new SingleChildScrollView(
        padding: new EdgeInsets.all(16.0),
        child: new Container(
          child: new Column(
            children: <Widget>[
              new Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  new Text('Your Peer ID: ' + myUniqueName),
                  new Text('NATS Server Address: ' + natsAddr),
                  new Text(status == 'connecting'
                      ? 'Connecting'
                      : status == 'connected'
                          ? 'Connected'
                          : status),
                ],
              ),
              new ListView.builder(
                physics: ScrollPhysics(),
                shrinkWrap: true,
                reverse: true,
                itemCount: listChat.length,
                itemBuilder: ((ctx, idx) {
                  return _msgContainer(listChat[idx]);
                }),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
                flex: 5,
                child: new Padding(
                  padding: new EdgeInsets.all(5.0),
                  child: new TextField(
                    controller: inputMsg,
                    decoration: new InputDecoration.collapsed(
                        hintText: 'Send a Message'),
                  ),
                )),
            Expanded(
              flex: 1,
              child: new TextButton.icon(
                  onPressed: _sendMessage,
                  icon: Icon(Icons.send),
                  label: new Text('')),
            )
          ],
        ),
        elevation: 9.0,
        shape: CircularNotchedRectangle(),
        color: Colors.white,
        notchMargin: 8.0,
      ),
    );
  }

  Widget _msgContainer(ChatMessage chat) {
    if (chat.sender != myUniqueName) {
      return new Container(
        decoration: new BoxDecoration(
            border: new Border.all(color: Colors.black),
            borderRadius: new BorderRadius.circular(10.0)),
        margin: new EdgeInsets.all(3.0),
        padding:
            new EdgeInsets.only(top: 16.0, bottom: 16.0, right: 8.0, left: 8.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new Text(
              'Other Peer ' + '(' + chat.date + ')',
              style: new TextStyle(color: Colors.grey),
            ),
            new Text(chat.content)
          ],
        ),
      );
    } else {
      return new Container(
        decoration: new BoxDecoration(
            border: new Border.all(color: Colors.black),
            borderRadius: new BorderRadius.circular(10.0)),
        margin: new EdgeInsets.all(3.0),
        padding:
            new EdgeInsets.only(top: 16.0, bottom: 16.0, right: 8.0, left: 8.0),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            new Text(
              'YOU',
              style: new TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            new Text(chat.content)
          ],
        ),
      );
    }
  }
}
