import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uber/model/user.dart' as new_user;

class FirebaseUser {

  static User getCurrentUsser() {

    FirebaseAuth auth = FirebaseAuth.instance;
    return auth.currentUser!;

  }

  static Future<new_user.User?> getLoggedUserData() async {

    User user = getCurrentUsser();
    String idUser = user.uid;

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentSnapshot<Map<String, dynamic>> snapshot = await db.collection('users')
    .doc(idUser)
    .get();

    Map<String, dynamic>? data = snapshot.data();

      String userType = data?['userType'];
      String email = data?['email'];
      String name = data?['name'];

      var newUser = new_user.User();
      newUser.idUser = idUser;
      newUser.userType = userType;
      newUser.email = email;
      newUser.name = name;

      return newUser;
  }

  static updateLocationData(String idRequisition, double latitude, double longitude, String type) async {

    FirebaseFirestore db = FirebaseFirestore.instance;
    new_user.User? user = await getLoggedUserData();
    user?.latitude = latitude;
    user?.longitude = longitude;

    print('user to map ');
    print('valor de user é ${user?.toMap()}');
    db.collection('requisitions')
    .doc(idRequisition)
    .update({
      '${type}': user?.toMap()
    });

  }

}