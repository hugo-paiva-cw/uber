import 'package:uber/model/destiny.dart';
import 'package:uber/model/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Requisition {

  late String _id;
  late String _status;
  late User _passenger;
  late User _driver;
  late Destiny _destiny;

  Requisition() {

    FirebaseFirestore db = FirebaseFirestore.instance;

    DocumentReference ref = db.collection('requisitions').doc();
    id = ref.id;

  }

  Map<String, dynamic> toMap() {

    Map<String, dynamic> passengerData = {
      'name': passenger.name,
      'email': passenger.email,
      'userType': passenger.userType,
      'idUser': passenger.idUser,
      'latitude': passenger.latitude,
      'longitude': passenger.longitude,
    };

    Map<String, dynamic> destinyData = {
      'street': destiny.street,
      'number': destiny.number,
      'neighborhood': destiny.neighborhood,
      'cep': destiny.cep,
      'latitude': destiny.latitude,
      'longitude': destiny.longitude,
    };

    Map<String, dynamic> requisitionData = {
      'id': id,
      'status': status,
      'passenger': passengerData,
      'driver': null,
      'destiny': destinyData
    };

    return requisitionData;
  }

  Destiny get destiny => _destiny;

  set destiny(Destiny value) {
    _destiny = value;
  }

  User get driver => _driver;

  set driver(User value) {
    _driver = value;
  }

  User get passenger => _passenger;

  set passenger(User value) {
    _passenger = value;
  }

  String get status => _status;

  set status(String value) {
    _status = value;
  }

  String get id => _id;

  set id(String value) {
    _id = value;
  }
}