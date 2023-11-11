// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'dart:convert';
// import 'dart:math';
// import 'package:http/http.dart' as http;
// import 'package:quasar/quasar.dart';

// import 'package:quasar_test/quasar.dart';
// import 'package:uuid/uuid.dart';

// void main() {
//   runApp(MaterialApp(
//     home: MyApp(),
//   ));
// }

// class ChatMessage {
//   String date, content, type, sender;
//   ChatMessage(this.date, this.type, this.content, this.sender);
// }

// class MyApp extends StatefulWidget {
//   @override
//   _State createState() => _State();
// }

// class _State extends State<MyApp> {
//   final uuid = Uuid();
//   late TextEditingController inputMsg, natServer;
//   List<ChatMessage> listChat = [];

//   String natsAddr = 'nats://demo.nats.io:4222';
//   late String myUniqueName;
//   late QuasarPeer me;
//   late QuasarServer server; // FOR DISCOVERING PEERS ONLY!
//   Timer? timer;

//   String status = 'Enter your NATS Address and Click Save';

//   @override
//   void initState() {
//     inputMsg = TextEditingController();
//     natServer = TextEditingController();
//     natServer.text = natsAddr;
//     myUniqueName = uuid.v4();

//     initPeers();
//   }

//   @override
//   dispose() {
//     me.close();
//   }

//   initPeers() async {
//     if (status == 'connected' || status == 'connecting') {
//       status = 'not connected';
//       await me.close();
//     }
//     me = QuasarPeer(myUniqueName, 'rendezvous', natsAddr);

//     status = 'connecting';

//     me.registerMethod('message', _getMessage);

//     me.listen().then((value) {
//       setState(() {
//         status = 'connected';
//       });
//     }).catchError((e) {
//       setState(() {
//         status = 'Error from peer';
//       });
//     });
//   }

//   void _sendMessage() async {
//     if (status == 'connected') {
//       me.sendNotification(
//           'message', {'type': 'text', 'content': inputMsg.text});
//       setState(() {
//         listChat.add(ChatMessage(
//             DateTime.now().toString(), 'text', inputMsg.text, myUniqueName));
//       });
//       inputMsg.clear();
//     }
//   }

//   void _getMessage(dynamic params) {

//     setState(() {
//       listChat.add(ChatMessage(DateTime.now().toString(), params.data['type'],
//           params.data['content'], 'someone-else'));
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       appBar: AppBar(
//         title: Text('Quasar Peer Chat app'),
//         actions: [
//           Padding(
//               padding: EdgeInsets.only(right: 20.0),
//               child: GestureDetector(
//                 onTap: () {
//                   showModalBottomSheet<void>(
//                     context: context,
//                     builder: (BuildContext context) {
//                       return SizedBox(
//                         height: 200,
//                         child: Center(
//                           child: Padding(
//                             padding: EdgeInsets.only(right: 20.0, left: 20.0),
//                             child: Column(
//                               mainAxisAlignment: MainAxisAlignment.center,
//                               children: <Widget>[
//                                 Padding(
//                                   padding: EdgeInsets.all(15),
//                                   child: TextField(
//                                     controller: natServer,
//                                     decoration: InputDecoration(
//                                       border: OutlineInputBorder(),
//                                       labelText: 'NATS Server Address',
//                                       hintText: 'Enter NATS Server Address',
//                                     ),
//                                   ),
//                                 ),
//                                 ElevatedButton(
//                                   child: const Text('Save'),
//                                   onPressed: () {
//                                     setState(() {
//                                       natsAddr = natServer.text;
//                                     });
//                                     initPeers();
//                                   },
//                                 )
//                               ],
//                             ),
//                           ),
//                         ),
//                       );
//                     },
//                   );
//                 },
//                 child: Icon(
//                   Icons.settings,
//                   size: 26.0,
//                 ),
//               ))
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: EdgeInsets.all(16.0),
//         child: Container(
//           child: Column(
//             children: <Widget>[
//               Column(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: <Widget>[
//                   Text('Your Peer ID: ' + myUniqueName),
//                   Text('NATS Server Address: ' + natsAddr),
//                   Text(status == 'connecting'
//                       ? 'Connecting'
//                       : status == 'connected'
//                           ? 'Connected'
//                           : status),
//                 ],
//               ),
//               ListView.builder(
//                 physics: ScrollPhysics(),
//                 shrinkWrap: true,
//                 reverse: true,
//                 itemCount: listChat.length,
//                 itemBuilder: ((ctx, idx) {
//                   return _msgContainer(listChat[idx]);
//                 }),
//               ),
//             ],
//           ),
//         ),
//       ),
//       bottomNavigationBar: BottomAppBar(
//         child: Row(
//           mainAxisSize: MainAxisSize.max,
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: <Widget>[
//             Expanded(
//                 flex: 5,
//                 child: Padding(
//                   padding: EdgeInsets.all(5.0),
//                   child: TextField(
//                     controller: inputMsg,
//                     decoration:
//                         InputDecoration.collapsed(hintText: 'Send a Message'),
//                   ),
//                 )),
//             Expanded(
//               flex: 1,
//               child: TextButton.icon(
//                   onPressed: _sendMessage,
//                   icon: Icon(Icons.send),
//                   label: Text('')),
//             )
//           ],
//         ),
//         elevation: 9.0,
//         shape: CircularNotchedRectangle(),
//         color: Colors.white,
//         notchMargin: 8.0,
//       ),
//     );
//   }

//   Widget _msgContainer(ChatMessage chat) {
//     if (chat.sender != myUniqueName) {
//       return Container(
//         decoration: BoxDecoration(
//             border: Border.all(color: Colors.black),
//             borderRadius: BorderRadius.circular(10.0)),
//         margin: EdgeInsets.all(3.0),
//         padding:
//             EdgeInsets.only(top: 16.0, bottom: 16.0, right: 8.0, left: 8.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: <Widget>[
//             Text(
//               'Other Peer ' + '(' + chat.date + ')',
//               style: TextStyle(color: Colors.grey),
//             ),
//             Text(chat.content)
//           ],
//         ),
//       );
//     } else {
//       return Container(
//         decoration: BoxDecoration(
//             border: Border.all(color: Colors.black),
//             borderRadius: BorderRadius.circular(10.0)),
//         margin: EdgeInsets.all(3.0),
//         padding:
//             EdgeInsets.only(top: 16.0, bottom: 16.0, right: 8.0, left: 8.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: <Widget>[
//             Text(
//               'YOU',
//               style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
//             ),
//             Text(chat.content)
//           ],
//         ),
//       );
//     }
//   }
// }
