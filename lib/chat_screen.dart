import 'dart:io';

import 'package:chat/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

import 'chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  
  final GoogleSignIn googleSignIn = GoogleSignIn();
  //final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  User? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((user) { 
      setState(() {
        _currentUser = user;
      });
    });

    
  }


  Future<User?> _getUser() async {
    if(_currentUser != null) return _currentUser;
    
    try {
      final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();
      final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount!.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleSignInAuthentication.idToken,
        accessToken: googleSignInAuthentication.accessToken
      );

      UserCredential authResult = await FirebaseAuth.instance.signInWithCredential(credential);

      User? user = authResult.user;

      return user;
    } catch (e) {
      return null;
    }
  }
  
  void _sendMessage({String? text, PickedFile? imgFile}) async {
    
    final User? user = await _getUser();

    if(user == null) {
      //_scaffoldKey.currentState.showSnackBar(snackbar);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível fazer o login. Tente novamente!'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    Map<String, dynamic> data = {
      'uid': user!.uid,
      'senderName': user.displayName,
      'senderPhotoUrl': user.photoURL,
      'time': Timestamp.now(),
    };

    if (imgFile != null) {
      File file = File(imgFile.path);

      UploadTask task = FirebaseStorage.instance.ref().child(
        user.uid + '_' + DateTime.now().millisecondsSinceEpoch.toString()
      ).putFile(file);

      setState(() {
        _isLoading = true;
      });

      TaskSnapshot taskSnapshot = await task;

      String url = await taskSnapshot.ref.getDownloadURL();
      //print('Teste de onde esta o download URL: $url');
      data['imgUrl'] = url;
    }

      setState(() {
        _isLoading = false;
      });

    if (text != null) data['text'] = text;

    FirebaseFirestore.instance.collection('messages').add(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          _currentUser !=null ? 'Olá ${_currentUser?.displayName}' : 'Chat App'
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          _currentUser != null ? IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              googleSignIn.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Você saiu com sucesso'),
                ),
              );
            }, 
          ) : Container(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance.collection('messages').orderBy('time').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.waiting:
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                default:
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>? documents = 
                    snapshot.data?.docs.reversed.toList();
                  return ListView.builder(
                    itemCount: documents?.length,
                    reverse: true, 
                    itemBuilder: (BuildContext context, int index) { 
                      return ChatMessage(
                        data: documents?[index].data(), 
                        mine: documents?[index].data()['uid'] == _currentUser?.uid
                      );
                    },
                  );
                }
              },
            ),
          ),
          _isLoading ? const LinearProgressIndicator() : Container(),
          TextComposer(_sendMessage),
        ],
      ),
    );
  }
}
