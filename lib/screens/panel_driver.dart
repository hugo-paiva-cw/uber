import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uber/utils/firebase_user.dart';
import 'package:uber/utils/status_requisition.dart';
import 'package:uber/model/user.dart' as new_user;

class PanelDriver extends StatefulWidget {
  const PanelDriver({Key? key}) : super(key: key);

  @override
  State<PanelDriver> createState() => _PanelDriverState();
}

class _PanelDriverState extends State<PanelDriver> {

  List<String> menuItems = ['Configurações', 'Deslogar'];
  final _controller = StreamController<QuerySnapshot<Map<String, dynamic>>>.broadcast();
  FirebaseFirestore db = FirebaseFirestore.instance;

  _signOutUser() {
    FirebaseAuth auth = FirebaseAuth.instance;

    auth.signOut();
    Navigator.pushReplacementNamed(context, '/');
  }

  _chooseMenuItem(String choice) {

    switch (choice) {
      case 'Deslogar':
        _signOutUser();
        break;
      case 'Configurações':
      // A little bit of settings
        break;
    }

  }

  Stream<QuerySnapshot> _addRequisitionListener() {
    
    final stream = db.collection('requisitions')
        .where('status', isEqualTo: StatusRequisition.WAITING)
        .snapshots();

    stream.listen((data) {
      _controller.add(data);
    });

    return _controller.stream;

  }

  _getActiveRequisitionDriver() async {

    User firebaseUser = FirebaseUser.getCurrentUsser();

    DocumentSnapshot<Map> documentSnapshot = await db.collection('active_requisition_driver')
    .doc( firebaseUser.uid ).get();

    var requisitionData = documentSnapshot.data();

    if (requisitionData == null) {
      _addRequisitionListener();
    } else {

      String idRequisition = requisitionData['id_requisition'];
      Navigator.pushReplacementNamed(
          context,
        '/ride',
        arguments: idRequisition
      );
    }


  }

  @override
  void initState() {
    super.initState();

    // _addRequisitionListener();

    _getActiveRequisitionDriver();

  }

  @override
  Widget build(BuildContext context) {

    var loadingMessage = Center(
      child: Column(
        children: const [
          Text('Carregando requisições'),
          CircularProgressIndicator()
        ],
      ),
    );

    var messageHasNoData = Center(
      child: Column(
        children: const [
          Text(
              'Você não tem nenhuma requisição :( ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold
            ),
          ),
          CircularProgressIndicator()
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel motorista'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _chooseMenuItem,
            itemBuilder: (context) {

              return menuItems.map((String item) {

                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );

              }).toList();

            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _controller.stream,
        builder: (context, snapshot) {
          switch ( snapshot.connectionState ) {
            case ConnectionState.none:
              break;
            case ConnectionState.waiting:
              return loadingMessage;
              break;
            case ConnectionState.active:
            case ConnectionState.done:

              if (snapshot.hasError) {
                return const Text('Erro ao carregar os dados!');
              } else {

                QuerySnapshot<Map<String,dynamic>>? querySnapshot = snapshot.data;

                if ( querySnapshot?.docs.length == 0) {
                  return messageHasNoData;
                } else {

                  return ListView.separated(
                    itemCount: querySnapshot!.docs.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 2,
                      color: Colors.grey,
                    ),
                    itemBuilder: (context, index) {

                      List<DocumentSnapshot> requisitions = querySnapshot.docs.toList();
                      DocumentSnapshot item = requisitions[index];

                      String idRequisition = item['id'];
                      String passengerName = item['passenger']['name'];
                      String street = item['destiny']['street'];
                      String number = item['destiny']['number'];

                      return ListTile(
                        title: Text(passengerName),
                        subtitle: Text('destino: $street, $number'),
                        onTap: () {
                          Navigator.pushNamed(
                              context,
                              '/ride',
                            arguments: idRequisition
                          );
                        },
                      );

                    },
                  );

                }
              }
          }
          return const Center(
            child: Text('Algo de errado ocorreu! Por favor carregue novamente!'),
          );

        },
      ),
    );
  }
}
