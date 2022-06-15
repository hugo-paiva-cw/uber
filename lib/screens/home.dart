import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../model/user.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {

  final TextEditingController _controllerEmail = TextEditingController(text: 'hugo@gmail.com');
  final TextEditingController _controllerPassword = TextEditingController(text: 'cueiozim');
  String _errorMessage = '';
  bool _isLoading = false;

  _validateFields() {

    String email = _controllerEmail.text;
    String password = _controllerPassword.text;

    // validate

      if (email.isNotEmpty && email.contains('@') ) {

        if (password.isNotEmpty && password.length >= 6) {

          User user = User();
          user.email = email;
          user.password = password;
          _logUser(user);

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
  }
  _logUser(User user) {
    setState(() {
      _isLoading = true;
    });

    FirebaseAuth auth = FirebaseAuth.instance;

    auth.signInWithEmailAndPassword(
        email: user.email,
        password: user.password
    ).then((firebaseUser) {

      _redirectPanelByUserType( firebaseUser.user!.uid );

    }).catchError((error) {
      _errorMessage = 'Erro ao autenticar usuário, verifique email e senha.';
    });

  }

  _redirectPanelByUserType(String idUser) async {

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot<Map> snapshot = await db.collection('users').doc(idUser).get();

    var data = snapshot.data();

    String userType = data!['userType'];

    setState(() {
      _isLoading = false;
    });

    switch( userType) {
      case 'driver':
        Navigator.pushReplacementNamed(context, '/panel-driver');
        break;
      case 'passenger':
        Navigator.pushReplacementNamed(context, '/panel-passenger');
        break;

    }

  }

  _verifyUserIsLogged() async {

    FirebaseAuth auth = FirebaseAuth.instance;

    var loggedUser = auth.currentUser;

    if ( loggedUser != null ) {
      String idUser = loggedUser.uid;
      _redirectPanelByUserType(idUser);
    }
  }

  @override
  void initState() {
    super.initState();

    _verifyUserIsLogged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/fundo.png'),
            fit: BoxFit.cover
          )
        ),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 200,
                    height: 150,
                  ),
                ),
                TextField(
                  controller: _controllerEmail,
                  autofocus: true,
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
                  padding: const EdgeInsets.only(top: 16, bottom: 10),
                  child: RaisedButton(
                    color: const Color(0xff1ebbd8),
                    onPressed: () {
                      _validateFields();

                    },
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
                    child: const Text(
                      'Entrar',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20
                      ),
                    ),
                  ),
                ),
                Center(
                  child: GestureDetector(
                    child: const Text(
                      'Não tem conta? Cadastre-se!',
                      style: TextStyle(
                          color: Colors.white
                      ),
                    ),
                    onTap: () {
                      Navigator.pushNamed(context, '/register');
                    },
                  ),
                ),
                _isLoading
                    ? const Center(child: CircularProgressIndicator(backgroundColor: Colors.white,),)
                    : Container(),
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
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
