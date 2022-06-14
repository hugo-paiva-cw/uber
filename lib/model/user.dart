
class User {

  late String _idUser;
  late String _name;
  late String _email;
  late String _password;
  late String _userType;

  late double _latitude;
  late double _longitude;

  User();

  double get latitude => _latitude;

  set latitude(double value) {
    _latitude = value;
  }

  Map<String, dynamic> toMap() {

    Map<String, dynamic> map = {
      'idUser'   : idUser,
      'name'     : name,
      'email'    : email,
      'userType' : userType,
      'latitude' : latitude,
      'longitude': longitude,
    };

    return map;
  }

  String verifyUserType(bool userType) {
    return userType ? 'driver' : 'passenger';
  }

  String get userType => _userType;

  set userType(String value) {
    _userType = value;
  }

  String get password => _password;

  set password(String value) {
    _password = value;
  }

  String get email => _email;

  set email(String value) {
    _email = value;
  }

  String get name => _name;

  set name(String value) {
    _name = value;
  }

  String get idUser => _idUser;

  set idUser(String value) {
    _idUser = value;
  }

  double get longitude => _longitude;

  set longitude(double value) {
    _longitude = value;
  }
}