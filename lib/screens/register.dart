import 'package:flutter/material.dart';
import 'package:uber/model/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;

class Register extends StatefulWidget {
  const Register({Key? key}) : super(key: key);

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {

  final TextEditingController _controllerName = TextEditingController(text: 'Hugo Sousa');
  final TextEditingController _controllerEmail = TextEditingController(text: 'hugo.motorista@gmail.com');
  final TextEditingController _controllerPassword = TextEditingController(text: 'cueiozim');
  bool _typeUser = false;
  String _errorMessage = '';

  _validateFields() {

    String name = _controllerName.text;
    String email = _controllerEmail.text;
    String password = _controllerPassword.text;

    // validate
    if (name.isNotEmpty) {

      if (email.isNotEmpty && email.contains('@') ) {


        if (password.isNotEmpty && password.length >= 6) {

          User user = User();
          user.name = name;
          user.email = email;
          user.password = password;
          user.userType = user.verifyUserType(_typeUser);
          _registerUser(user);

        } else {
          setState(() {
            _errorMessage = 'Preencha a senha com pelo menos 6 caracteres.';
          });
        }

      } else {
        setState(() {
          _errorMessage = 'Preencha o email válido.';
        });
      }

    } else {
      setState(() {
        _errorMessage = 'Preencha o nome.';
      });
    }

  }

  _registerUser(User user) {
    FirebaseAuth auth = FirebaseAuth.instance;
    FirebaseFirestore db = FirebaseFirestore.instance;

    auth.createUserWithEmailAndPassword(email: user.email, password: user.password)
        .then((value) {

      setState(() {
        _errorMessage = 'Usuário cadastrado com sucesso!';
      });

      db.collection('users')
          .doc(auth.currentUser!.uid)
          .set(user.toMap());

      switch( user.userType ) {
        case 'driver':
          Navigator.pushNamedAndRemoveUntil(context, '/panel-driver', (_) => false);
          break;
        case 'passenger':
          Navigator.pushNamedAndRemoveUntil(context, '/panel-passenger', (_) => false);
          break;
      }

    })
        .catchError((err) {
      setState(() {
        _errorMessage = 'Deu erro!';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro'),
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _controllerName,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                      fontSize: 20
                  ),
                  decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: 'Nome completo',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)
                      )
                  ),
                ),
                TextField(
                  controller: _controllerEmail,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                      fontSize: 20
                  ),
                  decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: 'e-mail',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)
                      )
                  ),
                ),
                TextField(
                  controller: _controllerPassword,
                  obscureText: true,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                      fontSize: 20
                  ),
                  decoration: InputDecoration(
                      contentPadding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                      hintText: 'senha',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6)
                      )
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Text('Passageiro'),
                      Switch(
                          value: _typeUser,
                          onChanged: (bool value) {
                            setState(() {
                              _typeUser = value;
                            });
                          }
                      ),
                      const Text('Motorista'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 10),
                  child: RaisedButton(
                    color: const Color(0xff1ebbd8),
                    onPressed: () {

                      _validateFields();
                    },
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                    child: const Text(
                      'Cadastrar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 20
                      ),
                    ),
                  ),
                )

              ],
            ),
          ),
        ),
      ),
    );
  }
}