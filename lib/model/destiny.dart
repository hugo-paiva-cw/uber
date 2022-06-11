class Destiny {
  late String _street;
  late String _number;
  late String _city;
  late String _neighborhood;
  late String _cep;
  late double _latitude;
  late double _longitude;

  Destiny();

  double get longitude => _longitude;

  set longitude(double value) {
    _longitude = value;
  }

  double get latitude => _latitude;

  set latitude(double value) {
    _latitude = value;
  }

  String get cep => _cep;

  set cep(String value) {
    _cep = value;
  }

  String get neighborhood => _neighborhood;

  set neighborhood(String value) {
    _neighborhood = value;
  }

  String get city => _city;

  set city(String value) {
    _city = value;
  }

  String get number => _number;

  set number(String value) {
    _number = value;
  }

  String get street => _street;

  set street(String value) {
    _street = value;
  }
}